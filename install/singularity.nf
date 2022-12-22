#!/usr/bin/env nextflow

/*

This file is part of geniac.

Copyright Institut Curie 2020.

This software is a computer program whose purpose is to perform
Automatic Configuration GENerator and Installer for nextflow pipeline.

You can use, modify and/ or redistribute the software under the terms
of license (see the LICENSE file for more details).

The software is distributed in the hope that it will be useful,
but "AS IS" WITHOUT ANY WARRANTY OF ANY KIND.
Users are therefore encouraged to test the software's suitability as regards
their requirements in conditions enabling the security of their systems and/or data.

The fact that you are presently reading this means that you have had knowledge
of the license and that you accept its terms.

*/

nextflow.enable.dsl=1

/**
 * CUSTOM FUNCTIONS
 **/

def addYumAndGitAndCmdConfs(List input) {
  List<String> gitList = []
  LinkedHashMap gitConf = params.geniac.containers?.git ?: [:]
  LinkedHashMap yumConf = params.geniac.containers?.yum ?: [:]
  LinkedHashMap cmdPostConf = params.geniac.containers?.cmd?.post ?: [:]
  LinkedHashMap cmdEnvConf = params.geniac.containers?.cmd?.envCustom ?: [:]
  (gitConf[input[0]] ?:'')
    .split()
    .each{ gitList.add(it.split('::')) }

  List result = new ArrayList<>(input)
  result.add(yumConf[input[0]])
  result.add(gitList)
  result.add(cmdPostConf[input[0]])
  result.add(cmdEnvConf[input[0]])
  return result
}

String buildCplmtGit(def gitEntries) {
  String cplmtGit = ''
  for (String[] tab : gitEntries) {
    cplmtGit += """ \\\\
    && mkdir /opt/\$(basename ${tab[0]} .git) && cd /opt/\$(basename ${tab[0]} .git) && git clone ${tab[0]} . && git checkout ${tab[1]}"""
  }

  return cplmtGit

}

String buildCplmtPath(List gitEntries) {
  String cplmtPath = ''
  for (String[] tab : gitEntries) {
    cplmtPath += "/opt/\$(basename ${tab[0]} .git):"
  }

  return cplmtPath
}


/**
 * CHANNELS INIT
 **/

condaPackagesCh = Channel.create()
condaFilesCh = Channel.create()
condaEnvsCh = Channel.create()
Channel
  .from(params.geniac.tools)
  .flatMap {
    List<String> result = []
    for (Map.Entry<String, String> entry : it.entrySet()) {
      if (entry.value instanceof String) {
        List<String> tab = entry.value.split()
        for (String s : tab) {
          result.add([entry.key, s.split('::')])
        }

        if (tab.size == 0) {
          result.add([entry.key, null])
        }
      } else {
        result.add([entry.key, entry.value])
      }
    }

    return result
  }.branch {
    condaExistingEnvsCh:
      (it[1] && it[1] instanceof Map)
      return [it[0], 'ENV']
    condaFilesCh:
      (it[1] && it[1][0].endsWith('.yml'))
      return [it[0], file(it[1][0])]
    condaPackagesCh: true
      return it
  }.set{ condaForks }

(condaExistingEnvs, condaFilesCh, condaPackagesCh) = [condaForks.condaExistingEnvsCh, condaForks.condaFilesCh, condaForks.condaPackagesCh]
condaExistingEnvs.into{ condaExistingEnvsCh; condaExistingRenvCh; condaExistingEnvsBisCh }
condaExistingRenvCh
  .filter {  it[0] =~/^renv.*/ }
  .set { condaFiles4Renv } // Channel for Renv environment

condaFiles4Renv.into{ condaFiles4SingularityRecipesCh4Renv; condaFilesOneEnvWithRenv; checkIsEmptyRenv }
condaPackagesCh.into{ condaPackages4SingularityRecipesCh; condaPackages4CondaEnvCh; condaPackagesUnfilteredCh }
condaFilesCh.into{ condaFiles4SingularityRecipesCh; condaFilesForCondaDepCh; condaFilesUnfilteredCh }

Channel
  .fromPath("${projectDir}/recipes/singularity/*.def")
  .map{ [it.simpleName, it] }
  .set{ singularityRecipeCh1 }

/**
 * CONDA RECIPES
 **/

Channel
  .fromPath("${projectDir}/recipes/conda/*.yml")
  .map{ [it.simpleName, it] }
  .set{ condaRecipes }


/**
 * DEPENDENCIES
 **/

Channel
  .fromPath("${projectDir}/recipes/dependencies/*", type: 'dir')
  .map{ [it.name, it] }
  .set{ fileDependencies }

/**
 * SOURCE CODE
 **/


Channel
  .fromPath("${projectDir}/modules/fromSource/*", type: 'dir')
  .map{ [it.name, it] }
  .into{ sourceCodeCh1; sourceCodeCh2; sourceCodeCh3; sourceCodeCh4; sourceCodeCh5 }



/**
 * PROCESSES
 **/
// TODO: use worklow.manifest.name for the name field
// TODO: check if it works with pip packages
// TODO: Add a process in order to test the generated environment.yml (create a venv from it, activate, export and check diffs)
// TODO: Check if order of dependencies can be an issue
condaChannelFromSpecsCh = Channel.create()
condaDepFromSpecsCh = Channel.create()
condaPackages4CondaEnvCh.separate(condaChannelFromSpecsCh, condaDepFromSpecsCh){ pTool -> [pTool[1][0], pTool[1][1]] }

process buildCondaDepFromRecipes {
  tag{ "condaDepBuild-" + key }

  input:
    set val(key), file(condaFile) from condaFilesForCondaDepCh

  output:
    file "condaChannels.txt" into condaChanFromFilesCh
    file "condaDependencies.txt" into condaDepFromFilesCh
    file "condaPipDependencies.txt" into condaPipDepFromFilesCh

  script:
    flags = 'BEGIN {flag=""} /channels/{flag="chan";next}  /dependencies/{flag="dep";next} /pip/{flag="pip";next}'
    """
    awk '${flags}  /^ *-/{if(flag == "chan"){print \$2}}' ${condaFile} > condaChannels.txt
    awk '${flags}  /^ *-/{if(flag == "dep"){print \$2}}' ${condaFile} > condaDependencies.txt
    awk '${flags}  /^ *-/{if(flag == "pip"){print \$2}}' ${condaFile} > condaPipDependencies.txt
    """
}

process buildCondaEnvFromCondaPackages {
  tag "condaEnvBuild"
  publishDir "${projectDir}/${params.publishDirConda}", overwrite: true, mode: 'copy'

  input:
    val condaDependencies from condaDepFromFilesCh.flatMap{ it.text.split() }.mix(condaDepFromSpecsCh).unique().toSortedList()
    val condaChannels from condaChanFromFilesCh.flatMap{ it.text.split() }.mix(condaChannelFromSpecsCh).filter(~/!(bioconda|conda-forge|defaults)/).unique().toSortedList().ifEmpty('NO_CHANNEL')
    val condaPipDependencies from condaPipDepFromFilesCh.flatMap{ it.text.split() }.unique().toSortedList().ifEmpty("")

  output:
    file("environment.yml")

  script:
    condaChansEnv = condaChannels != 'NO_CHANNEL' ? condaChannels : []
    condaDepEnv = String.join("\n      - ", condaDependencies)
    condaChanEnv = String.join("\n      - ", ["bioconda", "conda-forge", "defaults"] + condaChansEnv)
    condaPipDep = condaPipDependencies ? "\n      - pip:\n        - " + String.join("\n        - ", condaPipDependencies) : ""
    """
    cat << EOF > environment.yml
    # You can use this file to create a conda environment for this pipeline:
    #   conda env create -f environment.yml
    name: pipeline_env
    channels:
      - ${condaChanEnv}
    dependencies:
      - which
      - bc
      - pip
      - ${condaDepEnv}${condaPipDep}
    """
}

/**
 * default recipes
 **/

process buildDefaultSingularityRecipe {
  publishDir "${projectDir}/${params.publishDirDeffiles}", overwrite: true, mode: 'copy'

  output:
    set val(key), file("${key}.def") into singularityRecipeCh2

  script:
    key = 'onlyLinux'
    """
    cat << EOF > ${key}.def
    Bootstrap: docker
    From: ${params.dockerRegistry}${params.dockerLinuxDistro}

    %labels
        gitUrl ${params.gitUrl}
        gitCommit ${params.gitCommit}

    %environment
        export R_LIBS_USER="-"
        export R_PROFILE_USER="-"
        export R_ENVIRON_USER="-"
        export PYTHONNOUSERSITE=1
        export LC_ALL=en_US.utf-8
        export LANG=en_US.utf-8
    EOF
    """
}

process buildSingularityRecipeFromCondaFile {
  tag "${key}"
  publishDir "${projectDir}/${params.publishDirDeffiles}", overwrite: true, mode: 'copy'

  input:
    set val(key), file(condaFile), val(yum), val(git), val(cmdPost), val(cmdEnv) from condaFiles4SingularityRecipesCh
      // to prevent conda recipes for specific fromSourceCode cases
      .join(sourceCodeCh1, remainder: true)
      .filter{ it[1] && !it[2] }
      .map{ [it[0], it[1]] }
      .groupTuple()
      .map{ addYumAndGitAndCmdConfs(it) }

  output:
    set val(key), file("${key}.def") into singularityRecipeCh3

  script:
    def cplmtGit = buildCplmtGit(git)
    def cplmtPath = buildCplmtPath(git)
    def cplmtCmdPost = cmdPost ? '\\\\\n        && ' + cmdPost.join(' \\\\\n        && '): ''
    def cplmtCmdEnv = cmdEnv ? 'export ' + cmdEnv.join('\n        export '): ''
    def yumPkgs = yum ?: ''
    yumPkgs = git ? "${yumPkgs} git" : yumPkgs

    def cplmtYum = ''
    if ("${yumPkgs}${cplmtGit}".length()> 0 ) {
      cplmtYum = """${params.yum} install -y ${yumPkgs} ${cplmtGit} \\\\
        && """
    }

    """
    declare env_name=\$(head -1 ${condaFile} | cut -d' ' -f2)

    cat << EOF > ${key}.def
    Bootstrap: docker
    From: ${params.dockerRegistry}${params.dockerLinuxDistroConda}

    %labels
        gitUrl ${params.gitUrl}
        gitCommit ${params.gitCommit}

    %environment
        export R_LIBS_USER="-"
        export R_PROFILE_USER="-"
        export R_ENVIRON_USER="-"
        export PYTHONNOUSERSITE=1
        export PATH=${cplmtPath}\\\$PATH
        export LC_ALL=en_US.utf-8
        export LANG=en_US.utf-8
        source /opt/etc/bashrc
        ${cplmtCmdEnv}

    # real path from projectDir: ${condaFile}
    %files
        \$(basename ${condaFile}) /opt/\$(basename ${condaFile})

    %post
        ${cplmtYum}${params.yum} clean all \\\\
        && conda env create -f /opt/\$(basename ${condaFile}) \\\\
        && mkdir -p /opt/etc \\\\
        && echo -e "#! /bin/bash\\\\n\\\\n# script to activate the conda environment \${env_name}" > ~/.bashrc \\\\
        && conda init bash \\\\
        && echo "conda activate \${env_name}" >> ~/.bashrc \\\\
        && cp ~/.bashrc /opt/etc/bashrc \\\\
        && conda clean -a ${cplmtCmdPost}

    EOF
    """
}

process buildSingularityRecipeFromCondaFile4Renv {
  tag "${key}"
  publishDir "${projectDir}/${params.publishDirDeffiles}", overwrite: true, mode: 'copy'

  input:
    set val(key), file(condaFile), val(yum), val(git), val(cmdPost), val(cmdEnv) from condaFiles4SingularityRecipesCh4Renv
      // to prevent conda recipes for specific fromSourceCode cases
      .join(sourceCodeCh5, remainder: true)
      .filter{ it[1] && !it[2] }
      .map{ [it[0], it[1]] }
      .groupTuple()
      .map{ addYumAndGitAndCmdConfs(it) }

  output:
    set val(key), file("${key}.def") into singularityRecipeCh6

  script:
    def renvYml = params.geniac.tools.get(key).get('yml')
    def bioc = params.geniac.tools.get(key).get('bioc')
    def cplmtGit = buildCplmtGit(git)
    def cplmtPath = buildCplmtPath(git)
    def cplmtCmdPost = cmdPost ? '\\\\\n        && ' + cmdPost.join(' \\\\\n        && '): ''
    def cplmtCmdEnv = cmdEnv ? 'export ' + cmdEnv.join('\n        export '): ''
    def yumPkgs = yum ?: ''
    yumPkgs = git ? "${yumPkgs} git" : yumPkgs

    def cplmtYum = ''
    if ("${yumPkgs}${cplmtGit}".length()> 0 ) {
      cplmtYum = """${params.yum} install -y ${yumPkgs} ${cplmtGit} \\\\
        && """
    }

    """
    declare env_name=\$(head -1 ${renvYml} | cut -d' ' -f2)

    cat << EOF > ${key}.def
    Bootstrap: docker
    From: ${params.dockerRegistry}${params.dockerLinuxDistroConda}

    %setup
        mkdir -p \\\${SINGULARITY_ROOTFS}/opt/renv \\\${SINGULARITY_ROOTFS}/opt/renv_cache

    %labels
        gitUrl ${params.gitUrl}
        gitCommit ${params.gitCommit}

    %environment
        export R_LIBS_USER="-"
        export R_PROFILE_USER="-"
        export R_ENVIRON_USER="-"
        export PYTHONNOUSERSITE=1
        export PATH=${cplmtPath}\\\$PATH
        export LC_ALL=en_US.utf-8
        export LANG=en_US.utf-8
        source /opt/etc/bashrc
        ${cplmtCmdEnv}

    # real path from projectDir: ${renvYml}
    %files
        \$(basename ${renvYml}) /opt/\$(basename ${renvYml})
        ${key}/renv.lock /opt/renv/renv.lock

    %post
        R_MIRROR=https://cloud.r-project.org
        R_ENV_DIR=/opt/renv
        CACHE=TRUE
        CACHE_DIR=/opt/renv_cache
        ${cplmtYum}${params.yum} clean all \\\\
        && conda env create -f /opt/\$(basename ${renvYml}) \\\\
        && mkdir -p /opt/etc \\\\
        && echo -e "#! /bin/bash\\\\n\\\\n# script to activate the conda environment \${env_name}" > ~/.bashrc \\\\
        && conda init bash \\\\
        && echo "conda activate \${env_name}" >> ~/.bashrc \\\\
        && cp ~/.bashrc /opt/etc/bashrc \\\\
        && conda clean -a ${cplmtCmdPost}
        source /opt/etc/bashrc \\\\
        && R -q -e "options(repos = \\\\"\\\${R_MIRROR}\\\\") ; install.packages(\\\\"renv\\\\") ; options(renv.config.install.staged=FALSE, renv.settings.use.cache=FALSE) ; install.packages(\\\\"BiocManager\\\\"); BiocManager::install(version=\\\\"${bioc}\\\\", ask=FALSE) ; renv::restore(lockfile = \\\\"\\\${R_ENV_DIR}/renv.lock\\\\")"
   
    EOF
    """
}

/**
 * Build Singularity recipe from conda specifications in params.geniac.tools
 **/
process buildSingularityRecipeFromCondaPackages {
  tag "${key}"
  publishDir "${projectDir}/${params.publishDirDeffiles}", overwrite: true, mode: 'copy'

  input:
    set val(key), val(tools), val(yum), val(git), val(cmdPost), val(cmdEnv) from condaPackages4SingularityRecipesCh

      // to prevent conda recipes for specific fromSourceCode cases
      .join(sourceCodeCh2, remainder: true)
      .filter{ it[1] && !it[2] }

      .map{ [it[0], it[1]] }
      .groupTuple()
      .map{ addYumAndGitAndCmdConfs(it) }

  output:
    set val(key), file("${key}.def") into singularityRecipeCh4

  script:
    def cplmtGit = buildCplmtGit(git)
    def cplmtPath = buildCplmtPath(git)
    def cplmtCmdPost = cmdPost ? '\\\\\n        && ' + cmdPost.join(' \\\\\n        && '): ''
    def cplmtCmdEnv = cmdEnv ? 'export ' + cmdEnv.join('\n        export '): ''
    def yumPkgs = yum ?: ''
    yumPkgs = git ? "${yumPkgs} git" : yumPkgs


    List condaChannels = []
    List condaPackages = []
    for (String[] tab : tools) {
      if (!condaChannels.contains(tab[0])) {
        condaChannels.add(tab[0])
      }
      condaPackages.add(tab[1])
    }
    String  condaChannelsOption = condaChannels.collect() {"-c $it"}.join(' ')
    String  condaPackagesOption = condaPackages.collect() {"$it"}.join(' ')

    def cplmtYum = ''
    if ("${yumPkgs}${cplmtGit}".length()> 0 ) {
      cplmtYum = """${params.yum} install -y ${yumPkgs} ${cplmtGit} \\\\
        && """
    }

    """
    cat << EOF > ${key}.def
    Bootstrap: docker
    From: ${params.dockerRegistry}${params.dockerLinuxDistroConda}

    %labels
        gitUrl ${params.gitUrl}
        gitCommit ${params.gitCommit}

    %environment
        export R_LIBS_USER="-"
        export R_PROFILE_USER="-"
        export R_ENVIRON_USER="-"
        export PYTHONNOUSERSITE=1
        export PATH=${cplmtPath}\\\$PATH
        export LC_ALL=en_US.utf-8
        export LANG=en_US.utf-8
        source /opt/etc/bashrc
        ${cplmtCmdEnv}

    %post
        ${cplmtYum}${params.yum} clean all \\\\
        && conda create -y -n ${key}_env \\\\
        && conda install -y ${condaChannelsOption} -n ${key}_env ${condaPackagesOption} \\\\
        && mkdir -p /opt/etc \\\\
        && echo -e "#! /bin/bash\\\\n\\\\n# script to activate the conda environment ${key}_env" > ~/.bashrc \\\\
        && conda init bash \\\\
        && echo "conda activate ${key}_env" >> ~/.bashrc \\\\
        && cp ~/.bashrc /opt/etc/bashrc \\\\
        && conda clean -a ${cplmtCmdPost}

    EOF
    """
}


process buildSingularityRecipeFromSourceCode {
  tag "${key}"
  publishDir "${projectDir}/${params.publishDirDeffiles}", overwrite: true, mode: 'copy'

  input:
    set val(key), file(dir), val(yum), val(git), val(cmdPost), val(cmdEnv) from sourceCodeCh3.map{ addYumAndGitAndCmdConfs(it) }

  output:
    set val(key), file("${key}.def") into singularityRecipeCh5

  script:
    def cplmtGit = buildCplmtGit(git)
    def cplmtPath = buildCplmtPath(git)
    def cplmtCmdPost = cmdPost ? '\\\\\n        && ' + cmdPost.join(' \\\\\n        && '): ''
    def cplmtCmdEnv = cmdEnv ? 'export ' + cmdEnv.join('\n        export '): ''
    def yumPkgs = yum ?: ''
    yumPkgs = git ? "${yumPkgs} git" : yumPkgs


    def cplmtYum = ''
    if ("${yumPkgs}${cplmtGit}".length()> 0 ) {
      cplmtYum = """${params.yum} install -y ${yumPkgs} ${cplmtGit} \\\\
        && """
    }

    """

    image_name=\$(grep -q conda ${cmdPost} && echo "${params.dockerLinuxDistroConda}" || echo "${params.dockerLinuxDistro}")

    cat << EOF > ${key}.def
    Bootstrap: docker
    From: ${params.dockerRegistry}${params.dockerLinuxDistroSdk}
    Stage: devel

    %setup
        mkdir -p \\\${SINGULARITY_ROOTFS}/opt/modules

    %files
        ${key}/ /opt/modules

    %post
        ${cplmtYum}cd /opt/modules \\\\
        && mkdir build && cd build || exit \\\\
        && cmake3 ../${key} -DCMAKE_INSTALL_PREFIX=/usr/local/bin/${key} \\\\
        && make && make install ${cplmtCmdPost}

    Bootstrap: docker
    From: ${params.dockerRegistry}\${image_name}
    Stage: final

    %labels
        gitUrl ${params.gitUrl}
        gitCommit ${params.gitCommit}

    %files from devel
        /usr/local/bin/${key}/ /usr/local/bin/

    %post
        ${cplmtYum}${params.yum} install -y glibc-devel libstdc++-devel

    %environment
        export R_LIBS_USER="-"
        export R_PROFILE_USER="-"
        export R_ENVIRON_USER="-"
        export PYTHONNOUSERSITE=1
        export LC_ALL=en_US.utf-8
        export LANG=en_US.utf-8
        export PATH=/usr/local/bin/${key}:${cplmtPath}\\\$PATH
        ${cplmtCmdEnv}

    EOF
    """
}

// onlyCondaRecipeCh = condaPackagesUnfilteredCh.mix(condaFilesUnfilteredCh)
condaPackagesUnfilteredCh.mix(condaFilesUnfilteredCh).groupTuple().into {
  onlyCondaRecipe4buildCondaCh; onlyCondaRecipe4buildMulticondaCh
}


singularityRecipeCh6
  .concat(singularityRecipeCh5)
  .concat(singularityRecipeCh4)
  .concat(singularityRecipeCh3)
  .concat(singularityRecipeCh2)
  .concat(singularityRecipeCh1) // DONT'T MOVE: this channel must be the last one to be concatenated
  .groupTuple()
  .map{ key, tab -> [key, tab[0]] }
  .into {
    singularityAllRecipe4buildImagesCh; singularityAllRecipe4buildSingularityCh;
    singularityAllRecipe4buildDockerCh; singularityAllRecipe4buildPathCh
  }

process buildImages {
  maxForks 1
  tag "${key}"
  publishDir "${projectDir}/${params.publishDirSingularityImages}", overwrite: true, mode: 'copy'

  when:
    params.buildSingularityImages

  input:
    set val(key), file(singularityRecipe), file(fileDepDir), file(condaRecipe), file(sourceCodeDir) from singularityAllRecipe4buildImagesCh
      .join(fileDependencies, remainder: true)
      .join(condaRecipes, remainder: true)
      .join(sourceCodeCh4, remainder: true)
      .filter{ it[1] }

  output:
    file("${key.toLowerCase()}.sif")

  script:
    """
    singularity build ${params.singularityBuildOptions} ${key.toLowerCase()}.sif ${singularityRecipe}
    """
}


/**
 * Generate singularity.config
 **/

process buildSingularityConfig {
  tag "${key}"

  when:
    params.buildConfigFiles

  input:
    set val(key), file(singularityRecipe) from singularityAllRecipe4buildSingularityCh

  output:
    file("${key}SingularityConfig.txt") into mergeSingularityConfigCh

  script:
    """
    cat << EOF > "${key}SingularityConfig.txt"
      withLabel:${key}{ container = "\\\${params.geniac.singularityImagePath}/${key.toLowerCase()}.sif" }
    EOF
    """
}

process mergeSingularityConfig {
  tag "mergeSingularityConfig"
  publishDir "${projectDir}/${params.publishDirConf}", overwrite: true, mode: 'copy'

  when:
    params.buildConfigFiles

  input:
    file key from mergeSingularityConfigCh.toSortedList({ a, b -> a.getName().compareTo(b.getName()) }).dump(tag:"mergeSingularityConfigCh")

  output:
    file("singularity.config") into finalSingularityConfigCh

  script:
    """
    cat << EOF > "singularity.config"
    import java.io.File;
    import java.nio.file.Files;
    import java.nio.file.Path;
    import java.nio.file.Paths;
    import java.util.Arrays;
    import java.util.HashMap;
    import java.util.List;
    import java.util.Map;
    import java.util.Map.Entry;
    import java.util.regex.Matcher;
    import java.util.regex.Pattern;

    START_PATTERN = "__sta__";
    STOP_PATTERN = "__sto__";
    p1 = Pattern.compile("\\\"(.*?)\\\"");
    p2 = Pattern
            .compile("(" + START_PATTERN + "((?!" + STOP_PATTERN + ").)*?) +(.*?" + STOP_PATTERN + ")");
    SPECIAL_PATHS = Arrays.asList(new String[] { "\\\\\\\$PWD" });


    String sanitizePath(String path) throws Exception {
        if (path.endsWith("/")) {
            path = path.substring(0, path.length() - 1);
        }

        if (!path.startsWith("/") && !SPECIAL_PATHS.contains(path)) {
            path = "" + launchDir + "/" + path
        }

        return Paths.get(path).normalize().toString();
    }

    void checkPath(String source, String target, Map pathMap) {
        if ("\\\$HOME".contains(source)) {
            throw new Exception("ERROR reported from conf/singularity.config. \'" + source
                    + "\' is an invalid binding source. Indeed, as a result of this binding the user HOME directory would be available inside the container which can drive to unpredictible reproducibility issues. You should modify what was passed to the \'-Dap_mount_dir\' option during the cmake configuration step with geniac (see https://geniac.readthedocs.io and the FAQ).");
        }

        if (!target.startsWith("/")) {
            throw new Exception("ERROR reported from conf/singularity.config. \'" + target + "\' is an invalid binding target, it must be an absolute path. You should modify what was passed to the \'-Dap_mount_dir\' option during the cmake configuration step with geniac (see https://geniac.readthedocs.io and the FAQ).");
        }

        if (pathMap.containsKey(target) && !source.equals(pathMap.get(target))) {
            throw new Exception("Several bindings for to the same target " + target);
        }
    }

    void checkSamplePlan() {
        if (!params.samplePlan) {
            return;
        }

        singularity.runOptions += " -B " + params.samplePlan;

        Set set = [];
        (new File(params.samplePlan)).eachLine{
            defSamplePlanRow = it.split(",");
            nbCol = defSamplePlanRow.size();
            if(nbCol == 4) {
                r1Dir = defSamplePlanRow[2].substring(0, defSamplePlanRow[2].lastIndexOf("/"));
                r2Dir = defSamplePlanRow[3].substring(0, defSamplePlanRow[3].lastIndexOf("/"));
                set.add(r1Dir);
                set.add(r2Dir);
            } else if(nbCol == 3) {
                r1Dir = defSamplePlanRow[2].substring(0, defSamplePlanRow[2].lastIndexOf("/"));
                set.add(r1Dir);
            } else if(nbCol == 2) {
                r1Dir = defSamplePlanRow[1].substring(0, defSamplePlanRow[1].lastIndexOf("/"));
                set.add(r1Dir);
            }
            else {
                return;
            }
        };

        set.each{
            singularity.runOptions += " -B " + it;
        }
    }

    void checkSymlink(pathToCheck, add, map) {
        if (SPECIAL_PATHS.contains(pathToCheck)) {
            return;
        }

        if (add) {
            singularity.runOptions += " -B " + pathToCheck;
            map.put(pathToCheck, pathToCheck);
        }

        List<String> pathSteps = Arrays.asList(pathToCheck.split("/"));
        List<String> recursivePathsToCheck = new ArrayList<>();
        for (i = 1 ; i <= pathSteps.size() ; i++) {
            String currPathToCheck = pathSteps.subList(0, i).join("/");
            File f = new File(currPathToCheck);
            Path p = f.toPath();
            if (Files.isSymbolicLink(p)) {
                String symlinkPath = p.toRealPath();
                String nextPathToCheck = symlinkPath + "/" + pathSteps.subList(i, pathSteps.size()).join("/");
                recursivePathsToCheck.add(nextPathToCheck);
            }
        }

        checkSymlinks(recursivePathsToCheck, map);
    }

    void checkSymlinks(pathsToProcess, map) {
        for (String pathToProcess: pathsToProcess) {
            checkSymlink(pathToProcess, true, map);
        }
    }

    void checkBindings() throws Exception {
        singularity.runOptions += " -B \\\$projectDir,\\\$launchDir,\\\\\\\$PWD:/tmp,\\\\\\\$PWD:/var/tmp,\\\${params.genomeAnnotationPath?:''},\\\${params.outDir?:''},${params.mountDir?:''}";
        checkSamplePlan();
        String input = singularity.runOptions;

        // replace double quotes by start/stop pattern
        Matcher m = p1.matcher(input);
        if (m.find()) {
            input = m.replaceAll(START_PATTERN + "\\\\\\\$1" + STOP_PATTERN);
        }

        // replace spaces in start/stop pattern by ##
        m = p2.matcher(input);
        while (m.find()) {
            input = m.replaceAll("\\\\\\\$1##\\\\\\\$3");
            m = p2.matcher(input);
        }

        // split on remaining spaces
        String[] tab = input.split(" ");
        Map<String, String> pathMap = new HashMap<>();
        boolean curr = false;
        String newRunOptions = '';
        for (String inputElem : tab) {
            // binding option key
            if (inputElem.equals("-B") || inputElem.equals("--bind")) {
                curr = true;
            }
            // binding option value
            else if (!inputElem.startsWith("-") && curr) {
                // each path to bind
                for (String path : inputElem.split(",")) {
                    if (path.isEmpty()) {
                        continue;
                    }

                    // restore original value (revert p1/p2 pattern effects)
                    path = path.replaceAll("##", " ");
                    path = path.replaceAll(START_PATTERN, "\"");
                    path = path.replaceAll(STOP_PATTERN, "\"");

                    // source/target paths
                    String[] pathTab = path.split(":");

                    String target = null;
                    String source = sanitizePath(pathTab[0]);

                    if (pathTab.length > 1) {
                        target = sanitizePath(pathTab[1]);
                    } else {
                        target = source;
                    }

                    checkPath(source, target, pathMap);
                    pathMap.put(target, source);

                    // is symlink
                    checkSymlink(source, false, pathMap);
                }
            }
            // not binding option value/key
            else {
                newRunOptions += " " + inputElem;
                curr = false;
            }
        }

        newRunOptions += " -B ,";
        for (Entry<String, String> entry : pathMap.entrySet()) {
            System.out.println("path " + entry.getValue() + " mounted in " + entry.getKey() + ".");
            newRunOptions += entry.getValue() + (entry.getValue() == entry.getKey() ? '' : ":" + entry.getKey()) + ",";
        }

        singularity.runOptions = newRunOptions;
    }


    def checkProfileSingularity(path){
      if (new File(path).exists()){
        File directory = new File(path)
        def contents = []
        directory.eachFileRecurse (groovy.io.FileType.FILES){ file -> contents << file }
        if (!path?.trim() || contents == null || contents.size() == 0){
          System.out.println("   ### ERROR ###    The option '-profile singularity' requires the singularity images to be installed on your system. See \\`--singularityImagePath\\` for advanced usage.");
          System.exit(-1)
        }
      }else{
        System.out.println("   ### ERROR ###    The option '-profile singularity' requires the singularity images to be installed on your system. See \\`--singularityImagePath\\` for advanced usage.");
        System.exit(-1)
      }
    }

    singularity {
      enabled = true
      autoMounts = false
      runOptions = "--containall " + (params.geniac.containers?.singularityRunOptions ?: '').replace('-C', '').replace('--containall', '')
    }

    process {
      checkProfileSingularity("\\\${params.geniac.singularityImagePath}")
      checkBindings()
    EOF
    for keyFile in ${key}
    do
        cat \${keyFile} >> singularity.config
    done
    echo "}"  >> singularity.config
    """
}

/**
 * Generate docker.config
 **/

process buildDockerConfig {
  tag "${key}"

  when:
    params.buildConfigFiles

  input:
    set val(key), file(singularityRecipe) from singularityAllRecipe4buildDockerCh

  output:
    file("${key}DockerConfig.txt") into mergeDockerConfigCh

  script:
    """
    cat << EOF > "${key}DockerConfig.txt"
      withLabel:${key}{ container = "${key.toLowerCase()}" }
    EOF
    """
}

process mergeDockerConfig {
  tag "mergeDockerConfig"
  publishDir "${projectDir}/${params.publishDirConf}", overwrite: true, mode: 'copy'

  when:
    params.buildConfigFiles

  input:
    file key from mergeDockerConfigCh.toSortedList({ a, b -> a.getName().compareTo(b.getName()) }).dump(tag:"mergeDockerConfigCh")

  output:
    file("docker.config") into finalDockerConfigCh


  script:
    String volumeOptions = ""
    volumeOptions += "-v \\\\\\\$PWD:/tmp "
    volumeOptions += "-v \\\\\\\$PWD:/var/tmp "
    volumeOptions += "-v \\\${params.genomeAnnotationPath?:''}:\\\${params.genomeAnnotationPath?:''} "
    """
    cat << EOF > "docker.config"
    docker {
      enabled = true
      runOptions = "\\\${params.geniac.containers?.dockerRunOptions} ${volumeOptions}"
    }

    process {
    EOF
    for keyFile in ${key}
    do
        cat \${keyFile} >> docker.config
    done
    echo "}"  >> docker.config
    """
}

/**
 * Generate podman.config
 **/

process buildPodmanConfig {
  tag "buildPodmanConfig"
  publishDir "${projectDir}/${params.publishDirConf}", overwrite: true, mode: 'copy'

  when:
    params.buildConfigFiles

  input:
    file dockerConfig from finalDockerConfigCh

  output:
    file("podman.config") into finalPodmanConfigCh

  script:
    """
    sed -e "s/docker {/podman {/g" ${dockerConfig} > podman.config
    sed -i -e "s/dockerRunOptions/podmanRunOptions/g" podman.config
    """
}


/**
 * Generate conda.config
 **/

process buildCondaConfig {
  tag "${key}"

  when:
    params.buildConfigFiles

  input:
    set val(key), val(condaDef) from onlyCondaRecipe4buildCondaCh.mix(condaExistingEnvsCh)

  output:
    file("${key}CondaConfig.txt") into mergeCondaConfigCh

  script:
    if(condaDef == 'ENV'){
      condaValue = "\\\${params.geniac.tools?.${key}.env}"
    }else {
      condaValue = "\\\${projectDir}/environment.yml" 
    }

    """
    cat << EOF > "${key}CondaConfig.txt"
      withLabel:${key}{ conda = "${condaValue}" }
    EOF
    """
}

process mergeCondaConfig {
  tag "mergeCondaConfig"
  publishDir "${projectDir}/${params.publishDirConf}", overwrite: true, mode: 'copy'

  when:
    params.buildConfigFiles

  input:
    file key from mergeCondaConfigCh.toSortedList({ a, b -> a.getName().compareTo(b.getName()) }).dump(tag:"mergeCondaConfigCh")

  output:
    file("conda.config") into finalCondaConfigCh

  script:
    """
    echo -e "conda {\n  cacheDir = \\\"\\\${params.condaCacheDir}\\\"\n  createTimeout = '1 h'\n}\n" >> conda.config
    echo "process {"  >> conda.config
    echo "\n  beforeScript = \\\"export R_LIBS_USER=\\\\\\\"-\\\\\\\"; export R_PROFILE_USER=\\\\\\\"-\\\\\\\"; export R_ENVIRON_USER=\\\\\\\"-\\\\\\\"; export PYTHONNOUSERSITE=1; export PATH=\\\$PATH:\\\${projectDir}/bin/fromSource\\\"\n" >> conda.config
    for keyFile in ${key}
    do
        cat \${keyFile} >> conda.config
    done
    echo "}"  >> conda.config
    """
}

/**
 * Generate multiconda.config
 **/

process buildMulticondaConfig {
  tag "${key}"
  //publishDir "${projectDir}/${params.publishDirNextflowConf}", overwrite: true, mode: 'copy'

  when:
    params.buildConfigFiles

  input:
    set val(key), val(condaDef) from onlyCondaRecipe4buildMulticondaCh.mix(condaExistingEnvsBisCh)

  output:
    file("${key}MulticondaConfig.txt") into mergeMulticondaConfigCh

  script:
    cplmt = condaDef == 'ENV' ? '.env' : ''
    """
    cat << EOF > "${key}MulticondaConfig.txt"
      withLabel:${key}{ conda = "\\\${params.geniac.tools?.${key}${cplmt}}" }
    EOF
    """
    // withLabel:${key}{ conda = "\\\${params.geniac.tools?.${key}}" }
}

process mergeMulticondaConfig {
  tag "mergeMulticondaConfig"
  publishDir "${projectDir}/${params.publishDirConf}", overwrite: true, mode: 'copy'

  when:
    params.buildConfigFiles

  input:
    file key from mergeMulticondaConfigCh.toSortedList({ a, b -> a.getName().compareTo(b.getName()) }).dump(tag:"mergeMulticondaConfigCh")

  output:
    file("multiconda.config") into finalMulticondaConfigCh

  script:
    """
    echo -e "conda {\n  cacheDir = \\\"\\\${params.condaCacheDir}\\\"\n  createTimeout = '1 h'\n}\n" >> multiconda.config
    echo "process {"  >> multiconda.config
    echo "\n  beforeScript = \\\"export R_LIBS_USER=\\\\\\\"-\\\\\\\"; export R_PROFILE_USER=\\\\\\\"-\\\\\\\"; export R_ENVIRON_USER=\\\\\\\"-\\\\\\\"; export PYTHONNOUSERSITE=1; export PATH=\\\$PATH:\\\${projectDir}/bin/fromSource\\\"\n" >> multiconda.config
    for keyFile in ${key}
    do
        cat \${keyFile} >> multiconda.config
    done
    echo "}"  >> multiconda.config
    """
}

/**
 * Generate path.config
 **/

process buildMultiPathConfig {
  tag "${key}"
  //publishDir "${projectDir}/${params.publishDirNextflowConf}", overwrite: true, mode: 'copy'

  when:
    params.buildConfigFiles

  input:
    set val(key), file(singularityRecipe) from singularityAllRecipe4buildPathCh

  output:
    file("${key}MultiPathConfig.txt") into mergeMultiPathConfigCh
    file("${key}MultiPathLink.txt") into mergeMultiPathLinkCh

  script:
    """
    cat << EOF > "${key}MultiPathConfig.txt"
      withLabel:${key}{ beforeScript = "export PATH=\\\${params.geniac.multiPath}/${key}/bin:\\\$PATH" }
    EOF
    cat << EOF > "${key}MultiPathLink.txt"
    ${key}/bin
    EOF
    """
}

process mergeMultiPathConfig {
  tag "mergeMultiPathConfig"
  publishDir "${projectDir}/${params.publishDirConf}", overwrite: true, mode: 'copy'

  when:
    params.buildConfigFiles

  input:
    file key from mergeMultiPathConfigCh.toSortedList({ a, b -> a.getName().compareTo(b.getName()) }).dump(tag:"mergeMultiPathConfigCh")

  output:
    file("multipath.config") into finalMultiPathConfigCh

  script:
    def eofContent = """\
    cat << EOF > "multipath.config"
    def checkProfileMultipath(path){
      if (new File(path).exists()){
        File directory = new File(path)
        def contents = []
        directory.eachFileRecurse (groovy.io.FileType.FILES){ file -> contents << file }
        if (!path?.trim() || contents == null || contents.size() == 0){
          System.out.println("   ### ERROR ###   The option '-profile multipath' requires the configuration of each tool path. See \\`--globalPath\\` for advanced usage.");
          System.exit(-1)
        }
      }else{
        System.out.println("   ### ERROR ###   The option '-profile multipath' requires the configuration of each tool path. See \\`--globalPath\\` for advanced usage.");
        System.exit(-1)
      }
    }

    singularity {
      enabled = false
    }

    docker {
      enabled = false
    }

    EOF
    """.stripIndent()
    """
    ${eofContent}
    echo "process {"  >> multipath.config
    echo "  checkProfileMultipath(\\\"\\\${params.geniac.multiPath}\\\")" >> multipath.config
    for keyFile in ${key}
    do
        cat \${keyFile} >> multipath.config
    done
    echo "}"  >> multipath.config
    grep -v onlyLinux multipath.config > multipath.config.tmp
    mv multipath.config.tmp multipath.config
    """
}

process mergeMultiPathLink {
  tag "mergeMultiPathLink"
  publishDir "${projectDir}/${params.publishDirConf}", overwrite: true, mode: 'copy'

  when:
    params.buildConfigFiles

  input:
    file key from mergeMultiPathLinkCh.toSortedList({ a, b -> a.getName().compareTo(b.getName()) }).dump(tag:"mergeMultiPathLinkCh")

  output:
    file("multiPathLink.txt") into finalMultiPathLinkCh

  script:
    """
    for keyFile in ${key}
    do
        cat \${keyFile} >> multiPathLink.txt
    done
    grep -v onlyLinux multiPathLink.txt > multiPathLink.txt.tmp
    mv multiPathLink.txt.tmp multiPathLink.txt
    """
}

process clusterConfig {
  tag "clusterConfig"
  publishDir "${projectDir}/${params.publishDirConf}", overwrite: true, mode: 'copy'

  output:
    file("cluster.config")

  script:
    """
    cat << EOF > "cluster.config"
    /*
     * -------------------------------------------------
     *  Config the cluster profile and your scheduler
     * -------------------------------------------------
     */

    process {
      executor = '${params.clusterExecutor}'
      queue = params.queue ?: null
    }
    """
}

process globalPathConfig {
  tag "globalPathConfig"
  publishDir "${projectDir}/${params.publishDirConf}", overwrite: true, mode: 'copy'

  output:
    file("path.config") into finalPathConfigCh
    file("PathLink.txt") into finalPathLinkCh

  script:
    """
    cat << EOF > "path.config"
    def checkProfilePath(path){
      if (new File(path).exists()){
        File directory = new File(path)
        def contents = []
        directory.eachFileRecurse (groovy.io.FileType.FILES){ file -> contents << file }
        if (!path?.trim() || contents == null || contents.size() == 0){
          System.out.println("   ### ERROR ###   The option '-profile path' requires the configuration of each tool path. See \\`--globalPath\\` for advanced usage.");
          System.exit(-1)
        }
      }else{
        System.out.println("   ### ERROR ###   The option '-profile path' requires the configuration of each tool path. See \\`--globalPath\\` for advanced usage.");
        System.exit(-1)
      }
    }

    singularity {
      enabled = false
    }

    docker {
      enabled = false
    }

    process {
      checkProfilePath("\\\${params.geniac.path}")
      beforeScript = "export PATH=\\\${params.geniac.path}:\\\$PATH"
    }
    EOF
    cat << EOF > "PathLink.txt"
    bin
    EOF
    """
}



workflow.onComplete {
  Map endSummary = [:]
  endSummary['Completed on'] = workflow.complete
  endSummary['Duration']     = workflow.duration
  endSummary['Success']      = workflow.success
  endSummary['exit status']  = workflow.exitStatus
  endSummary['Error report'] = workflow.errorReport ?: '-'
  endSummary['Distro Linux'] = "${params.dockerLinuxDistro}"
  endSummary['Distro Linux / Conda'] ="${params.dockerLinuxDistroConda}"
  endSummary['Docker registry'] = "${params.dockerRegistry}"
  endSummary['Cluster executor'] = "${params.clusterExecutor}"
  String endWfSummary = endSummary.collect { k,v -> "${k.padRight(30, '.')}: $v" }.join("\n")
  println endWfSummary

}

