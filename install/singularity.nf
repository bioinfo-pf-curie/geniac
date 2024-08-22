#!/usr/bin/env nextflow

/*

This file is part of geniac.

Copyright Institut Curie 2020-2024.

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

nextflow.enable.dsl=2

/********************
 * CUSTOM FUNCTIONS *
 ********************/

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


/*****************
 * CHANNELS INIT *
 *****************/

// Channel with conda env info form geniac.config
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

(condaExistingEnvsCh, condaFilesCh, condaPackagesCh) = [condaForks.condaExistingEnvsCh, condaForks.condaFilesCh, condaForks.condaPackagesCh]

condaPackagesCh
  .multiMap { pTool -> 
    condaChannelFromSpecs: pTool[1][0]
    condaDepFromSpecs: pTool[1][1]
  }
  .set { condaPackages }

// The 2 following channels contain information
// about conda env defined in the geniac.config file
condaChannelFromSpecsCh = condaPackages.condaChannelFromSpecs
condaDepFromSpecsCh = condaPackages.condaDepFromSpecs

// Channel for Renv environment
condaExistingEnvsCh
  .filter {  it[0] =~/^renv.*/ }
  .set { condaFiles4Renv }

// SINGULARITY RECIPES
Channel
  .fromPath("${projectDir}/recipes/singularity/*.def")
  .map{ [it.simpleName, it] }
  .set{ singularityRecipesCh }

// CONDA RECIPES
Channel
  .fromPath("${projectDir}/recipes/conda/*.yml")
  .map{ [it.simpleName, it] }
  .set{ condaRecipesCh }

// DEPENDENCIES
Channel
  .fromPath("${projectDir}/recipes/dependencies/*", type: 'dir')
  .map{ [it.name, it] }
  .ifEmpty(['NO_DEPENDENCIES', file('NO_DEPENDENCIES')])
  .set{ fileDependenciesCh }

// SOURCE CODE
Channel
  .fromPath("${projectDir}/modules/fromSource/*", type: 'dir')
  .map{ [it.name, it] }
  .set{ sourceCodeCh }

// CONTAINER LIST
if(params.containerList != null) {

  Channel
    .fromPath(params.containerList)
    .splitCsv()
    .set{ containerListCh }

}


/*************
 * PROCESSES *
 *************/

/**
 *
 * singularity profile
 *
 * Geniac documentation:
 *   - https://geniac.readthedocs.io/en/latest/run.html#run-profile-singularity
 *
 **/

//////////////////////
// STEP - ONLYLINUX //
//////////////////////

// This process creates the container recipe for the onlyLinux label.
// Geniac documentation:
//   - https://geniac.readthedocs.io/en/latest/process.html#process-unix
process buildDefaultSingularityRecipe {
  publishDir "${projectDir}/${params.publishDirDeffiles}", overwrite: true, mode: 'copy'

  output:
    tuple val(key), path("${key}.def"), emit: singularityRecipes
    tuple val(key), path("${key}.sha256sum"), emit: sha256sum

  script:
    key = 'onlyLinux'
    """
    # write recipe
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
    
    # compute hash digest of the recipe using:
    #   - only the recipe
    cat ${key}.def | grep -v gitCommit | grep -v gitUrl | sha256sum  | awk '{print \$1}' | sed -e 's/\$/ ${key}/g' > ${key}.sha256sum
    """
}

//////////////////////
// STEP - CONDA ENV //
//////////////////////

// This process creates the container recipes for each tool defined as a conda env with the
// packages listed in params.geniac.tools.
// Geniac documentation:
//   - https://geniac.readthedocs.io/en/latest/process.html#easy-install-with-conda
process buildSingularityRecipeFromCondaPackages {
  tag "${key}"
  publishDir "${projectDir}/${params.publishDirDeffiles}", overwrite: true, mode: 'copy'

  input:
    tuple val(key), val(tools), val(yum), val(git), val(cmdPost), val(cmdEnv)

  output:
    tuple val(key), file("${key}.def"), emit: singularityRecipes
    tuple val(key), path("${key}.sha256sum"), emit: sha256sum

  script:
    def cplmtGit = buildCplmtGit(git)
    def cplmtPath = buildCplmtPath(git)
    if ("${cplmtPath}".length()> 0 ) {
      cplmtPath += ":"
    }

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
      cplmtYum = """${params.yum} install ${params.yumOptions} -y ${yumPkgs} ${cplmtGit} \\\\
        && """
    }

    """
    # write the recipe
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
        && CONDA_ROOT=\\\$(conda info --system | grep CONDA_ROOT | awk '{print \\\$2}') \\\\
        && micromamba install --root-prefix \\\${CONDA_ROOT} -y ${condaChannelsOption} -n ${key}_env ${condaPackagesOption} \\\\
        && mkdir -p /opt/etc \\\\
        && echo -e "#! /bin/bash\\\\n\\\\n# script to activate the conda environment ${key}_env" > ~/.bashrc \\\\
        && conda init bash \\\\
        && echo "conda activate ${key}_env" >> ~/.bashrc \\\\
        && cp ~/.bashrc /opt/etc/bashrc \\\\
        && conda clean -y -a \\\\
        && micromamba clean -y -a ${cplmtCmdPost}

    EOF

    # compute hash digest of the recipe using
    #  - only the recipe file without the labels
    cat ${key}.def | grep -v gitCommit | grep -v gitUrl | sha256sum  | awk '{print \$1}' | sed -e 's/\$/ ${key}/g' > ${key}.sha256sum
    """
}

// This process creates the container recipes for each tool defined as a conda env from a yml file
// Geniac documentation:
//   - https://geniac.readthedocs.io/en/latest/process.html#process-custom-conda
process buildSingularityRecipeFromCondaFile {
  tag "${key}"
  publishDir "${projectDir}/${params.publishDirDeffiles}", overwrite: true, mode: 'copy'

  input:
    tuple val(key), path(condaFile), val(yum), val(git), val(cmdPost), val(cmdEnv)

  output:
    tuple val(key), path("${key}.def"), emit: singularityRecipes
    tuple val(key), path("${key}.sha256sum"), emit: sha256sum

  script:
    def cplmtGit = buildCplmtGit(git)
    def cplmtPath = buildCplmtPath(git)
    if ("${cplmtPath}".length()> 0 ) {
      cplmtPath += ":"
    }
    def cplmtCmdPost = cmdPost ? '\\\\\n        && ' + cmdPost.join(' \\\\\n        && '): ''
    def cplmtCmdEnv = cmdEnv ? 'export ' + cmdEnv.join('\n        export '): ''
    def yumPkgs = yum ?: ''
    yumPkgs = git ? "${yumPkgs} git" : yumPkgs

    def cplmtYum = ''
    if ("${yumPkgs}${cplmtGit}".length()> 0 ) {
      cplmtYum = """${params.yum} install ${params.yumOptions} -y ${yumPkgs} ${cplmtGit} \\\\
        && """
    }

    """
    declare env_name=\$(head -1 ${condaFile} | cut -d' ' -f2)

    # write the recipe
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
        && CONDA_ROOT=\\\$(conda info --system | grep CONDA_ROOT | awk '{print \\\$2}') \\\\
        && micromamba env create --root-prefix \\\${CONDA_ROOT} -f /opt/\$(basename ${condaFile}) \\\\
        && mkdir -p /opt/etc \\\\
        && echo -e "#! /bin/bash\\\\n\\\\n# script to activate the conda environment \${env_name}" > ~/.bashrc \\\\
        && conda init bash \\\\
        && echo "conda activate \${env_name}" >> ~/.bashrc \\\\
        && cp ~/.bashrc /opt/etc/bashrc \\\\
        && conda clean -y -a \\\\
        && micromamba clean -y -a ${cplmtCmdPost}

    EOF
    # compute hash digest of the recipe using:
    #   - the recipe file without the labels / comments
    #   - the conda yml
    cat ${key}.def ${condaFile} | grep -v gitCommit | grep -v gitUrl | grep -v "real path from projectDir" | sha256sum | awk '{print \$1}' | sed -e 's/\$/ ${key}/g' > ${key}.sha256sum
    """
}

// This process creates the container recipes for each tool defined as a Renv.
// Geniac documentation:
//   - https://geniac.readthedocs.io/en/latest/process.html#r-packages-using-renv
process buildSingularityRecipeFromCondaFile4Renv {
  tag "${key}"
  publishDir "${projectDir}/${params.publishDirDeffiles}", overwrite: true, mode: 'copy'

  input:
    tuple val(key), val(condaEnv), val(yum), val(git), val(cmdPost), val(cmdEnv), path(dependencies)

  output:
    tuple val(key), path("${key}.def"), emit: singularityRecipes
    tuple val(key), path("${key}.sha256sum"), emit: sha256sum

  script:
    def renvYml = params.geniac.tools.get(key).get('yml')
    def bioc = params.geniac.tools.get(key).get('bioc')
    def cplmtGit = buildCplmtGit(git)
    def cplmtPath = buildCplmtPath(git)
    if ("${cplmtPath}".length()> 0 ) {
      cplmtPath += ":"
    }
    def cplmtCmdPost = cmdPost ? '\\\\\n        && ' + cmdPost.join(' \\\\\n        && '): ''
    def cplmtCmdEnv = cmdEnv ? 'export ' + cmdEnv.join('\n        export '): ''
    def yumPkgs = yum ?: ''
    yumPkgs = git ? "${yumPkgs} git" : yumPkgs

    def cplmtYum = ''
    if ("${yumPkgs}${cplmtGit}".length()> 0 ) {
      cplmtYum = """${params.yum} install ${params.yumOptions} -y ${yumPkgs} ${cplmtGit} \\\\
        && """
    }

    """
    declare env_name=\$(head -1 ${renvYml} | cut -d' ' -f2)

    # write the recipe
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

    # real path from projectDir: ${renvYml}
    %files
        \$(basename ${renvYml}) /root/\$(basename ${renvYml})
        ${key}/renv.lock /root/renv.lock

    %post
        R_MIRROR=https://cloud.r-project.org
        R_ENV_DIR=/opt/renv
        CACHE=TRUE
        CACHE_DIR=/opt/renv_cache
        mkdir -p /opt/renv /opt/renv_cache
        mv /root/\$(basename ${renvYml}) /opt/\$(basename ${renvYml})
        mv /root/renv.lock /opt/renv/renv.lock
        ${cplmtYum}${params.yum} clean all \\\\
        && CONDA_ROOT=\\\$(conda info --system | grep CONDA_ROOT | awk '{print \\\$2}') \\\\
        && micromamba env create --root-prefix \\\${CONDA_ROOT} -f /opt/\$(basename ${renvYml}) \\\\
        && mkdir -p /opt/etc \\\\
        && echo -e "#! /bin/bash\\\\n\\\\n# script to activate the conda environment \${env_name}" > ~/.bashrc \\\\
        && conda init bash \\\\
        && echo "conda activate \${env_name}" >> ~/.bashrc \\\\
        && cp ~/.bashrc /opt/etc/bashrc \\\\
        && conda clean -y -a \\\\
        && micromamba clean -y -a ${cplmtCmdPost}
        source /opt/etc/bashrc \\\\
        && R -q -e "options(repos = \\\\"\\\${R_MIRROR}\\\\") ; install.packages(\\\\"renv\\\\") ; options(renv.config.install.staged=FALSE, renv.settings.use.cache=FALSE) ; install.packages(\\\\"BiocManager\\\\"); BiocManager::install(version=\\\\"${bioc}\\\\", ask=FALSE) ; renv::restore(lockfile = \\\\"\\\${R_ENV_DIR}/renv.lock\\\\")"
   
    EOF

    # compute hash digest of the recipe using:
    #   - the recipe file without the labels
    #   - the conda yml
    #   - the renv.lock
    cat ${key}.def ${renvYml} ${key}/renv.lock | grep -v gitCommit | grep -v gitUrl | grep -v "real path from projectDir" | sha256sum | awk '{print \$1}' | sed -e 's/\$/ ${key}/g' > ${key}.sha256sum
    """
}

////////////////////////
// STEP - SOURCE CODE //
////////////////////////

// This process creates the container recipes for each tool installed from source code.
// Geniac documentation.
//   - https://geniac.readthedocs.io/en/latest/process.html#install-from-source-code
process buildSingularityRecipeFromSourceCode {
  tag "${key}"
  publishDir "${projectDir}/${params.publishDirDeffiles}", overwrite: true, mode: 'copy'

  input:
    tuple val(key), file(sourceCode), val(yum), val(git), val(cmdPost), val(cmdEnv)

  output:
    tuple  val(key), path("${key}.def"), emit: singularityRecipes
    tuple val(key), path("${key}.sha256sum"), emit: sha256sum

  script:
    def cplmtGit = buildCplmtGit(git)
    def cplmtPath = buildCplmtPath(git)
    if ("${cplmtPath}".length()> 0 ) {
      cplmtPath += ":"
    }
    def cplmtCmdPost = cmdPost ? '\\\\\n        && ' + cmdPost.join(' \\\\\n        && '): ''
    def cplmtCmdEnv = cmdEnv ? 'export ' + cmdEnv.join('\n        export '): ''
    def yumPkgs = yum ?: ''
    yumPkgs = git ? "${yumPkgs} git" : yumPkgs


    def cplmtYum = ''
    if ("${yumPkgs}${cplmtGit}".length()> 0 ) {
      cplmtYum = """${params.yum} install ${params.yumOptions} -y ${yumPkgs} ${cplmtGit} \\\\
        && """
    }

    """

    image_name=\$(grep -q conda ${cmdPost} && echo "${params.dockerLinuxDistroConda}" || echo "${params.dockerLinuxDistro}")

    # write the recipe
    cat << EOF > ${key}.def
    Bootstrap: docker
    From: ${params.dockerRegistry}${params.dockerLinuxDistroSdk}
    Stage: devel

    %files
        ${key}/ /root/

    %post
        mkdir -p /opt/modules
        mv /root/${key}/ /opt/modules
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
        ${cplmtYum}${params.yum} install ${params.yumOptions} -y glibc-devel libstdc++-devel

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

    # compute hash digest of the recipe using:
    #   - the recipe file without the labels / comments
    #   - the source code
    tar --mtime='1970-01-01' -cf ${key}.tar -C ${key} --sort=name --group=0 --owner=0 --numeric-owner --mode=777 .
    grep -v gitCommit ${key}.def | grep -v gitUrl > ${key}-nolabels.def 
    cat ${key}.tar ${key}-nolabels.def | sha256sum | awk '{print \$1}' | sed -e 's/\$/ ${key}/g' > ${key}.sha256sum
    """
}

/////////////////////////////
// STEP - BUILD CONTAINERS //
/////////////////////////////

// This process creates the containers for all the tools
process buildImages {
  maxForks 1
  tag "${key}"
  publishDir "${projectDir}/${params.publishDirSingularityImages}", overwrite: true, mode: 'copy'

  when:
    params.buildSingularityImages

  input:
    tuple val(key), file(singularityRecipe), file(fileDepDir), file(condaRecipe), file(sourceCodeDir)

  output:
    path("${key.toLowerCase()}.sif")

  script:
    """
    singularity build ${params.singularityBuildOptions} ${key.toLowerCase()}.sif ${singularityRecipe}
    """

  stub:
    """
    touch ${key.toLowerCase()}.sif
    """
}

/**
 *
 * conda profile
 *
 * Geniac documentation:
 *   - https://geniac.readthedocs.io/en/latest/run.html#run-profile-conda
 *
 **/

// This process parses each conda recipe (yml file) and creates 3 files with:
//  - the list of channels used in the recipe
//  - the list of dependencies (i.e. conda package name)
//  - le list of pip dependencies (i.e. pip package name)
process buildCondaDepFromRecipes {
  tag{ "condaDepBuild-" + key }

  input:
    tuple val(key), file(condaFile)

  output:
    path "condaChannels.txt", emit: condaChanFromFiles
    path "condaDependencies.txt", emit: condaDepFromFiles
    path "condaPipDependencies.txt", emit: condaPipDepFromFiles

  script:
    flags = 'BEGIN {flag=""} /channels/{flag="chan";next}  /dependencies/{flag="dep";next} /pip/{flag="pip";next}'
    """
    awk '${flags}  /^ *-/{if(flag == "chan"){print \$2}}' ${condaFile} > condaChannels.txt
    awk '${flags}  /^ *-/{if(flag == "dep"){print \$2}}' ${condaFile} > condaDependencies.txt
    awk '${flags}  /^ *-/{if(flag == "pip"){print \$2}}' ${condaFile} > condaPipDependencies.txt
    """
}


// This process generate a single conda recipe (environment.yml file)
// which contains all the conda packages defined in both
// the geniac.config file and the yml files.
// This recipe will make it possible to use the 'conda' profile
process buildCondaEnvFromCondaPackages {
  tag "condaEnvBuild"
  publishDir "${projectDir}/${params.publishDirConda}", overwrite: true, mode: 'copy'

  input:
    val(condaDependencies)
    val(condaChannels)
    val(condaPipDependencies)

  output:
    path("environment.yml")

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
 *
 * singularity profiles and config files
 *
 * Geniac documentation:
 *   - https://geniac.readthedocs.io/en/latest/run.html#profiles
 *
 **/


/////////////////////////////
// STEP - apptainer config //
/////////////////////////////

// This process create on file for each tool to declare its 'withLabel' parameter.
process buildApptainerConfig {
  tag "${key}"

  when:
    params.buildConfigFiles

  input:
    tuple val(key), path(singularityRecipe)

  output:
    path("${key}ApptainerConfig.txt"), emit: mergeApptainerConfig

  script:
    """
    cat << EOF > "${key}ApptainerConfig.txt"
      withLabel:${key}{ container = "\\\${params.geniac.singularityImagePath}/${key.toLowerCase()}.sif" }
    EOF
    """
}


// This process concatenates the outputs from buildApptainerConfig
// to create the apptainer.config file.
process mergeApptainerConfig {
  tag "mergeApptainerConfig"
  publishDir "${projectDir}/${params.publishDirConf}", overwrite: true, mode: 'copy'

  when:
    params.buildConfigFiles

  input:
    path(key)

  output:
    path("apptainer.config")

  script:
    """
    cat << EOF > "apptainer.config"
    import java.io.File;

    def checkProfileApptainer(path){
      if (new File(path).exists()){
        File directory = new File(path)
        def contents = []
        directory.eachFileRecurse (groovy.io.FileType.FILES){ file -> contents << file }
        if (!path?.trim() || contents == null || contents.size() == 0){
          System.out.println("   ### ERROR ###    The option '-profile apptainer' requires the apptainer images to be installed on your system. See \\`--apptainerImagePath\\` for advanced usage.");
          System.exit(-1)
        }
      } else {
        System.out.println("   ### ERROR ###    The option '-profile apptainer' requires the apptainer images to be installed on your system. See \\`--apptainerImagePath\\` for advanced usage.");
        System.exit(-1)
      }
    }

    apptainer {
      enabled = true
      autoMounts = true
      runOptions = (params.geniac.containers?.apptainerRunOptions ?: '')
    }

    process {
      checkProfileApptainer("\\\${params.geniac.apptainerImagePath}")
    EOF
    for keyFile in ${key}
    do
        cat \${keyFile} >> apptainer.config
    done
    echo "}"  >> apptainer.config
    """
}




//////////////////////////
// STEP - docker config //
//////////////////////////

// This process creates one file for each tool to declare its 'withLabel' parameter.
process buildDockerConfig {
  tag "${key}"

  when:
    params.buildConfigFiles

  input:
    tuple val(key), path(singularityRecipe)

  output:
    path("${key}DockerConfig.txt"), emit: mergeDockerConfig

  script:
    """
    cat << EOF > "${key}DockerConfig.txt"
      withLabel:${key}{ container = "${key.toLowerCase()}" }
    EOF
    """
}

// This process concatenates the outputs from buildDockerConfig
// to create the docker.config file.
process mergeDockerConfig {
  tag "mergeDockerConfig"
  publishDir "${projectDir}/${params.publishDirConf}", overwrite: true, mode: 'copy'

  when:
    params.buildConfigFiles

  input:
    path(key)

  output:
    path("docker.config"), emit: dockerConfig


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

//////////////////////////
// STEP - conda config //
//////////////////////////

// This process creates one file for each tool to declare its 'withLabel' parameter.
process buildCondaConfig {
  tag "${key}"

  when:
    params.buildConfigFiles

  input:
    tuple val(key), val(condaDef)

  output:
    path("${key}CondaConfig.txt"), emit: mergeCondaConfig

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

// This process concatenates the outputs from buildCondaConfig
// to create the conda.config file.
process mergeCondaConfig {
  tag "mergeCondaConfig"
  publishDir "${projectDir}/${params.publishDirConf}", overwrite: true, mode: 'copy'

  when:
    params.buildConfigFiles

  input:
    path(key)

  output:
    path("conda.config")

  script:
    """
    echo -e "conda {\n  cacheDir = \\\"\\\${params.condaCacheDir}\\\"\n  createTimeout = '1 h'\n  enabled = 'true'\n}\n" >> conda.config
    echo "process {"  >> conda.config
    echo "\n  beforeScript = \\\"export R_LIBS_USER=\\\\\\\"-\\\\\\\"; export R_PROFILE_USER=\\\\\\\"-\\\\\\\"; export R_ENVIRON_USER=\\\\\\\"-\\\\\\\"; export PYTHONNOUSERSITE=1; export PATH=\\\$PATH:\\\${projectDir}/bin/fromSource\\\"\n" >> conda.config
    for keyFile in ${key}
    do
        cat \${keyFile} >> conda.config
    done
    echo "}"  >> conda.config
    """
}



//////////////////////////////
// STEP - multiconda config //
//////////////////////////////

// This process creates one file for each tool to declare its 'withLabel' parameter.
process buildMulticondaConfig {
  tag "${key}"
  //publishDir "${projectDir}/${params.publishDirNextflowConf}", overwrite: true, mode: 'copy'

  when:
    params.buildConfigFiles

  input:
    tuple val(key), val(condaDef)

  output:
    path("${key}MulticondaConfig.txt"), emit:mergeMulticondaConfig

  script:
    cplmt = condaDef == 'ENV' ? '.env' : ''
    """
    cat << EOF > "${key}MulticondaConfig.txt"
      withLabel:${key}{ conda = "\\\${params.geniac.tools?.${key}${cplmt}}" }
    EOF
    """
}

// This process concatenates the outputs from buildCondaConfig
// to create the conda.config file.
process mergeMulticondaConfig {
  tag "mergeMulticondaConfig"
  publishDir "${projectDir}/${params.publishDirConf}", overwrite: true, mode: 'copy'

  when:
    params.buildConfigFiles

  input:
    path(key)

  output:
    path("multiconda.config")

  script:
    """
    echo -e "conda {\n  cacheDir = \\\"\\\${params.condaCacheDir}\\\"\n  createTimeout = '1 h'\n  enabled = 'true'\n}\n" >> multiconda.config
    echo "process {"  >> multiconda.config
    echo "\n  beforeScript = \\\"export R_LIBS_USER=\\\\\\\"-\\\\\\\"; export R_PROFILE_USER=\\\\\\\"-\\\\\\\"; export R_ENVIRON_USER=\\\\\\\"-\\\\\\\"; export PYTHONNOUSERSITE=1; export PATH=\\\$PATH:\\\${projectDir}/bin/fromSource\\\"\n" >> multiconda.config
    for keyFile in ${key}
    do
        cat \${keyFile} >> multiconda.config
    done
    echo "}"  >> multiconda.config
    """
}

/////////////////////////////
// STEP - multipath config //
/////////////////////////////

// This process creates one file for each tool to declare its 'withLabel' parameter.
process buildMultiPathConfig {
  tag "${key}"
  //publishDir "${projectDir}/${params.publishDirNextflowConf}", overwrite: true, mode: 'copy'

  when:
    params.buildConfigFiles

  input:
    tuple val(key), file(singularityRecipe)

  output:
    path("${key}MultiPathConfig.txt"), emit: mergeMultiPathConfig
    path("${key}MultiPathLink.txt"), emit: mergeMultiPathLink

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

// This process concatenates the outputs from buildCondaConfig
// to create the multipath.config file.
process mergeMultiPathConfig {
  tag "mergeMultiPathConfig"
  publishDir "${projectDir}/${params.publishDirConf}", overwrite: true, mode: 'copy'

  when:
    params.buildConfigFiles

  input:
    path(key)

  output:
    path("multipath.config")

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


// This process creates a file that will be used in cmake script.
process mergeMultiPathLink {
  tag "mergeMultiPathLink"
  publishDir "${projectDir}/${params.publishDirConf}", overwrite: true, mode: 'copy'

  when:
    params.buildConfigFiles

  input:
    path(key) // from mergeMultiPathLinkCh.toSortedList({ a, b -> a.getName().compareTo(b.getName()) }).dump(tag:"mergeMultiPathLinkCh")

  output:
    path("multiPathLink.txt") // into finalMultiPathLinkCh

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

/////////////////////////////
// STEP - path config //
/////////////////////////////

// This process creates the path.config file.
// It also creates a file needed by cmake.
process globalPathConfig {
  tag "globalPathConfig"
  publishDir "${projectDir}/${params.publishDirConf}", overwrite: true, mode: 'copy'

  output:
    path("path.config")
    path("PathLink.txt")

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

//////////////////////////
// STEP - podman config //
//////////////////////////

// This process creates the podman.config file from the docker.config file.
process buildPodmanConfig {
  tag "buildPodmanConfig"
  publishDir "${projectDir}/${params.publishDirConf}", overwrite: true, mode: 'copy'

  when:
    params.buildConfigFiles

  input:
    path(dockerConfig)

  output:
    path("podman.config")

  script:
    """
    sed -e "s/docker {/podman {/g" ${dockerConfig} > podman.config
    sed -i -e "s/dockerRunOptions/podmanRunOptions/g" podman.config
    """
}

///////////////////////////////
// STEP - singularity config //
///////////////////////////////

// This process create on file for each tool to declare its 'withLabel' parameter.
process buildSingularityConfig {
  tag "${key}"

  when:
    params.buildConfigFiles

  input:
    tuple val(key), path(singularityRecipe)

  output:
    path("${key}SingularityConfig.txt"), emit: mergeSingularityConfig

  script:
    """
    cat << EOF > "${key}SingularityConfig.txt"
      withLabel:${key}{ container = "\\\${params.geniac.singularityImagePath}/${key.toLowerCase()}.sif" }
    EOF
    """
}


// This process concatenates the outputs from buildSingularityConfig
// to create the singularity.config file.
process mergeSingularityConfig {
  tag "mergeSingularityConfig"
  publishDir "${projectDir}/${params.publishDirConf}", overwrite: true, mode: 'copy'

  when:
    params.buildConfigFiles

  input:
    path(key)

  output:
    path("singularity.config")

  script:
    """
    cat << EOF > "singularity.config"
    import java.io.File;

    def checkProfileSingularity(path){
      if (new File(path).exists()){
        File directory = new File(path)
        def contents = []
        directory.eachFileRecurse (groovy.io.FileType.FILES){ file -> contents << file }
        if (!path?.trim() || contents == null || contents.size() == 0){
          System.out.println("   ### ERROR ###    The option '-profile singularity' requires the singularity images to be installed on your system. See \\`--singularityImagePath\\` for advanced usage.");
          System.exit(-1)
        }
      } else {
        System.out.println("   ### ERROR ###    The option '-profile singularity' requires the singularity images to be installed on your system. See \\`--singularityImagePath\\` for advanced usage.");
        System.exit(-1)
      }
    }

    singularity {
      enabled = true
      autoMounts = true
      runOptions = (params.geniac.containers?.singularityRunOptions ?: '')
    }

    process {
      checkProfileSingularity("\\\${params.geniac.singularityImagePath}")
    EOF
    for keyFile in ${key}
    do
        cat \${keyFile} >> singularity.config
    done
    echo "}"  >> singularity.config
    """
}


/******************
 * SHA256SUM file *
 ******************/

// This process computes the sha256sum for the recipes written manually
// Geniac documentation:
//   - https://geniac.readthedocs.io/en/latest/run.html#cluster
process sha256sumManualRecipes {
  tag "${key}"
  publishDir "${projectDir}/${params.publishDirDeffiles}", overwrite: true, mode: 'copy'

  input:
    tuple val(key), path(recipe), file(fileDependencies)

  output:
    tuple val(key), path("${key}.sha256sum"), emit: sha256sum

  script:
    """
    if [[ -d ${key} ]] ; then
    tar --mtime='1970-01-01' -cf ${key}.tar -C ${key} --sort=name --group=0 --owner=0 --numeric-owner --mode=777 .
      cat ${key}.tar ${recipe} | sha256sum | awk '{print \$1}' | sed -e 's/\$/ ${key}/g' > ${key}.sha256sum
    else
      sha256sum ${recipe} | awk '{print \$1}' | sed -e 's/\$/ ${key}/g' > ${key}.sha256sum
    fi
    """
}

// This process concatenates all the sha256sum files into a single file
process sha256sumFile {
  tag "sha256sum"
  publishDir "${projectDir}/${params.publishDirDeffiles}", overwrite: true, mode: 'copy'

  input:
    path("*")

  output:
    path("sha256sum")

  script:
    """
    cat *.sha256sum > sha256sum
    """
}


/**
 *
 * cluster config
 *
 * Geniac documentation:
 *   - https://geniac.readthedocs.io/en/latest/run.html#cluster
 *
 **/

// This process creates the cluster.config file.
process clusterConfig {
  tag "clusterConfig"
  publishDir "${projectDir}/${params.publishDirConf}", overwrite: true, mode: 'copy'

  output:
    path("cluster.config")

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

workflow {
  main:

  // Get conda en information from yml files
  buildCondaDepFromRecipes(condaFilesCh)

  // Create the conda env used by the 'conda' profile
  buildCondaEnvFromCondaPackages(
    buildCondaDepFromRecipes.out.condaDepFromFiles
     .flatMap{ it.text.split() }
     .mix(condaDepFromSpecsCh)
     .unique()
     .toSortedList(),
    buildCondaDepFromRecipes.out.condaChanFromFiles
      .flatMap{ it.text.split() }
      .mix(condaChannelFromSpecsCh)
      .filter(~/!(bioconda|conda-forge|defaults)/) // only official channels are allowed
      .unique()
      .toSortedList()
      .ifEmpty('NO_CHANNEL'),
    buildCondaDepFromRecipes.out.condaPipDepFromFiles
      .flatMap{ it.text.split() }
      .unique()
      .toSortedList()
      .ifEmpty("")
  )

  ///////////////////////////
  // STEP - CREATE RECIPES //
  ///////////////////////////

  // Create the onlyLinux container recipe
  buildDefaultSingularityRecipe()

  // Create the container recipes for each tool defined with a list of packages in geniac.config
  buildSingularityRecipeFromCondaPackages(
    condaPackagesCh
      // to prevent conda recipes for specific fromSourceCode cases
      .join(sourceCodeCh, remainder: true)
      .filter{ it[1] && !it[2] }
      .map{ [it[0], it[1]] }
      .groupTuple()
      .map{ addYumAndGitAndCmdConfs(it) }
  )

  // Create the container recipes for each tool defined as a conda env from a yml file
  buildSingularityRecipeFromCondaFile(
    condaFilesCh
      // to prevent conda recipes for specific fromSourceCode cases
      .join(sourceCodeCh, remainder: true)
      .filter{ it[1] && !it[2] }
      .map{ [it[0], it[1]] }
      .groupTuple()
      .map{ addYumAndGitAndCmdConfs(it) }
  )

  // Create the container recipes for each tool defined as a Renv
  buildSingularityRecipeFromCondaFile4Renv(
    condaFiles4Renv
      // to prevent conda recipes for specific fromSourceCode cases
      .join(sourceCodeCh, remainder: true)
      .filter{ it[1] && !it[2] }
      .map{ [it[0], it[1]] }
      .groupTuple()
      .map{ addYumAndGitAndCmdConfs(it) }
      .join(fileDependenciesCh)
  )

  // Create the container recipes for each tool installed from source code
  buildSingularityRecipeFromSourceCode(
    sourceCodeCh
      .map{ addYumAndGitAndCmdConfs(it) }
  )

  // SHA256SUM
  sha256sumManualRecipes(
    singularityRecipesCh
      .combine(
        fileDependenciesCh
          .map{ it[1] }
          .collect()
          .toList()
      )
  )

  buildSingularityRecipeFromCondaFile4Renv.out.sha256sum
    .concat(buildSingularityRecipeFromSourceCode.out.sha256sum)
    .concat(buildSingularityRecipeFromCondaPackages.out.sha256sum)
    .concat(buildSingularityRecipeFromCondaFile.out.sha256sum)
    .concat(buildDefaultSingularityRecipe.out.sha256sum)
    .concat(sha256sumManualRecipes.out.sha256sum)
    .set{ sha256sumCh }

  // Select the list of tools if containerList has been provided
  if (params.containerList != null) {
    sha256sumCh
      .join(containerListCh)
      .set{ sha256sumCh }
  }

  sha256sumFile(
    sha256sumCh
      .map{ it[1] }
      .collect()
  )

  /////////////////////////////
  // STEP - BUILD CONTAINERS //
  /////////////////////////////

  // Create a channel with all the container recipes
  buildSingularityRecipeFromCondaFile4Renv.out.singularityRecipes
    .concat(buildSingularityRecipeFromSourceCode.out.singularityRecipes)
    .concat(buildSingularityRecipeFromCondaPackages.out.singularityRecipes)
    .concat(buildSingularityRecipeFromCondaFile.out.singularityRecipes)
    .concat(buildDefaultSingularityRecipe.out.singularityRecipes)
    .concat(singularityRecipesCh)
    // je pense que les deux lignes de dessous ne servent à rien
    //.groupTuple()
    //.map{ key, tab -> [key, tab[0]] }
    .set {singularityAllRecipes}

  // Select the list of tools if containerList has been provided
  if (params.containerList != null) {
    singularityAllRecipes
      .join(containerListCh)
      .set{ singularityAllRecipes }
  }

  // Create all the containers
  buildImages(
    singularityAllRecipes
      .join(fileDependenciesCh, remainder: true)
      .join(condaRecipesCh, remainder: true)
      .join(sourceCodeCh, remainder: true)
      .filter{ it[1] }
  )
  
  ////////////////////////////////
  // STEP - CREATE CONFIG FILES //
  ///////////////////////////////

  // Create the apptainer config 
  buildApptainerConfig(singularityAllRecipes)
  mergeApptainerConfig(
    buildApptainerConfig.out.mergeApptainerConfig
      .toSortedList({ a, b -> a.getName().compareTo(b.getName()) }))

  // Create the conda config
  buildCondaConfig(
    condaPackagesCh
      .mix(condaFilesCh)
      .groupTuple()
      .mix(condaExistingEnvsCh)
  )
  mergeCondaConfig(
    buildCondaConfig.out.mergeCondaConfig
      .toSortedList({ a, b -> a.getName().compareTo(b.getName()) })
  )

  // Create the cluster config 
  clusterConfig()

  // Create the docker config 
  buildDockerConfig(singularityAllRecipes)
  mergeDockerConfig(
    buildDockerConfig.out.mergeDockerConfig
      .toSortedList({ a, b -> a.getName().compareTo(b.getName()) }))

  // Create the multiconda config
  buildMulticondaConfig(
    condaPackagesCh
      .mix(condaFilesCh)
      .groupTuple()
      .mix(condaExistingEnvsCh)
  )
  mergeMulticondaConfig(
    buildMulticondaConfig.out.mergeMulticondaConfig
      .toSortedList({ a, b -> a.getName().compareTo(b.getName()) })
  )

  // Create the multipath config 
  buildMultiPathConfig(singularityAllRecipes)
  mergeMultiPathConfig(
    buildMultiPathConfig.out.mergeMultiPathConfig
      .toSortedList({ a, b -> a.getName().compareTo(b.getName()) })
  )
  mergeMultiPathLink(
    buildMultiPathConfig.out.mergeMultiPathLink
      .toSortedList({ a, b -> a.getName().compareTo(b.getName()) })
  )

  // Create the path config 
  globalPathConfig()

  // Create the podman config 
  buildPodmanConfig(mergeDockerConfig.out.dockerConfig)

  // Create the singularity config 
  buildSingularityConfig(singularityAllRecipes)
  mergeSingularityConfig(
    buildSingularityConfig.out.mergeSingularityConfig
      .toSortedList({ a, b -> a.getName().compareTo(b.getName()) }))

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

