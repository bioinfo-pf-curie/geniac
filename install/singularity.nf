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


/**
 * CUSTOM FUNCTIONS
 **/

def addYumAndGitToCondaCh(List condaIt) {
  List<String> gitList = []
  LinkedHashMap gitConf = params.geniac.containers.git ?: [:]
  LinkedHashMap yumConf = params.geniac.containers.yum ?: [:]
  (gitConf[condaIt[0]] ?:'')
    .split()
    .each{ gitList.add(it.split('::')) }

  return [
    condaIt[0],
    condaIt[1],
    yumConf[condaIt[0]],
    gitList
  ]
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
}.set { condaForks }
(condaExistingEnvsCh, condaFilesCh, condaPackagesCh) = [condaForks.condaExistingEnvsCh, condaForks.condaFilesCh, condaForks.condaPackagesCh]
condaPackagesCh.into { condaPackages4SingularityRecipesCh; condaPackages4CondaEnvCh; condaPackagesUnfilteredCh }
condaFilesCh.into { condaFiles4SingularityRecipesCh; condaFilesForCondaDepCh; condaFilesUnfilteredCh }


Channel
  .fromPath("${projectDir}/recipes/singularity/*.def")
  .map { [it.simpleName, it] }
  .set { singularityRecipeCh1 }

/**
 * CONDA RECIPES
 **/

Channel
  .fromPath("${projectDir}/recipes/conda/*.yml")
  .set { condaRecipes }


/**
 * DEPENDENCIES
 **/

Channel
  .fromPath("${projectDir}/recipes/dependencies/*")
  .set { fileDependencies }

/**
 * SOURCE CODE
 **/


Channel
  .fromPath("${projectDir}/modules", type: 'dir', checkIfExists: true)
  .set { sourceCodeDirCh }


Channel
  .fromPath("${projectDir}/modules/*.sh")
  .map {
    return [it.simpleName, it]
  }.into { sourceCodeCh1; sourceCodeCh2; sourceCodeCh3 }



/**
 * PROCESSES
 **/
// TODO: use worklow.manifest.name for the name field
// TODO: check if it works with pip packages
// TODO: Add a process in order to test the generated environment.yml (create a venv from it, activate, export and check diffs)
// TODO: Check if order of dependencies can be an issue
condaChannelFromSpecsCh = Channel.create()
condaDepFromSpecsCh = Channel.create()
condaPackages4CondaEnvCh.separate(condaChannelFromSpecsCh, condaDepFromSpecsCh) { pTool -> [pTool[1][0], pTool[1][1]] }

process buildCondaDepFromRecipes {
  tag { "condaDepBuild-" + key }

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
    val condaDependencies from condaDepFromFilesCh.flatMap { it.text.split() }.mix(condaDepFromSpecsCh).unique().toSortedList()
    val condaChannels from condaChanFromFilesCh.flatMap { it.text.split() }.mix(condaChannelFromSpecsCh).filter(~/!(bioconda|conda-forge|defaults)/).unique().toSortedList().ifEmpty('NO_CHANNEL')
    val condaPipDependencies from condaPipDepFromFilesCh.flatMap { it.text.split() }.unique().toSortedList().ifEmpty("")

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
    From: ${params.dockerRegistry}centos:7

    %labels
        gitUrl ${params.gitUrl}
        gitCommit ${params.gitCommit}

    %post
        yum install -y which \\\\
        && yum clean all

    %environment
        LC_ALL=en_US.utf-8
        LANG=en_US.utf-8
    EOF
    """
}

process buildSingularityRecipeFromCondaFile {
  tag "${key}"
  publishDir "${projectDir}/${params.publishDirDeffiles}", overwrite: true, mode: 'copy'

  input:
    set val(key), file(condaFile), val(yum), val(git) from condaFiles4SingularityRecipesCh
      .join(sourceCodeCh1, remainder: true)
      .filter { it[2] == null }
      .map { [it[0], it[1]] }
      .groupTuple()
      .map { addYumAndGitToCondaCh(it) }

  output:
    set val(key), file("${key}.def") into singularityRecipeCh3

  script:
    def cplmtGit = buildCplmtGit(git)
    def cplmtPath = buildCplmtPath(git)
    def yumPkgs = yum ?: ''
    yumPkgs = git ? "${yumPkgs} git" : yumPkgs

    """
    declare env_name=\$(head -1 ${condaFile} | cut -d' ' -f2)

    cat << EOF > ${key}.def
    Bootstrap: docker
    From: ${params.dockerRegistry}conda/miniconda3-centos7

    %labels
        gitUrl ${params.gitUrl}
        gitCommit ${params.gitCommit}

    %environment
        PATH=/usr/local/envs/\${env_name}/bin:${cplmtPath}\\\$PATH
        LC_ALL=en_US.utf-8
        LANG=en_US.utf-8

    # real path from projectDir: ${condaFile}
    %files
        \$(basename ${condaFile}) /opt/\$(basename ${condaFile})

    %post
        yum install -y which ${yumPkgs} ${cplmtGit} \\\\
        && yum clean all \\\\
        && conda env create -f /opt/\$(basename ${condaFile}) \\\\
        && echo "source activate \${env_name}" > ~/.bashrc \\\\
        && conda clean -a

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
    set val(key), val(tools), val(yum), val(git) from condaPackages4SingularityRecipesCh
      .join(sourceCodeCh2, remainder: true)
      .filter { it[2] == null }
      .map { [it[0], it[1]] }
      .groupTuple()
      .map { addYumAndGitToCondaCh(it) }

  output:
    set val(key), file("${key}.def") into singularityRecipeCh4

  script:
    def cplmtGit = buildCplmtGit(git)
    def cplmtPath = buildCplmtPath(git)
    def yumPkgs = yum ?: ''
    yumPkgs = git ? "${yumPkgs} git" : yumPkgs

    def cplmtConda = ''
    for (String[] tab : tools) {
      cplmtConda += """ \\\\
        && conda install -y -c ${tab[0]} -n ${key}_env ${tab[1]}"""
    }

    """
    cat << EOF > ${key}.def
    Bootstrap: docker
    From: ${params.dockerRegistry}conda/miniconda3-centos7

    %labels
        gitUrl ${params.gitUrl}
        gitCommit ${params.gitCommit}

    %environment
        PATH=/usr/local/envs/${key}_env/bin:${cplmtPath}\\\$PATH
        LC_ALL=en_US.utf-8
        LANG=en_US.utf-8

    %post
        yum install -y which ${yumPkgs} ${cplmtGit} \\\\
        && yum clean all \\\\
        && conda create -y -n ${key}_env ${cplmtConda} \\\\
        && echo "source activate ${key}_env" > ~/.bashrc \\\\
        && conda clean -a

    EOF
    """
}


process buildSingularityRecipeFromSourceCode {
  tag "${key}"
  publishDir "${projectDir}/${params.publishDirDeffiles}", overwrite: true, mode: 'copy'

  input:
    set val(key), file(installFile) from sourceCodeCh3

  output:
    set val(key), file("${key}.def") into singularityRecipeCh5

  script:
    """
    image_name=\$(grep -q conda ${installFile} && echo "conda/miniconda3-centos7" || echo "centos:7")
    cat << EOF > ${key}.def
    Bootstrap: docker
    From: ${params.dockerRegistry}\${image_name}
    Stage: devel

    %setup
        mkdir -p \\\${SINGULARITY_ROOTFS}/opt/modules

    %files
        modules/${installFile} /opt/modules
        modules/${key}/ /opt/modules

    %post
        yum install -y which epel-release \\\\
        && yum repolist \\\\
        && yum install -y gcc gcc-c++ make \\\\
        && cd /opt/modules \\\\
        && bash ${installFile} \\\\

    Bootstrap: docker
    From: ${params.dockerRegistry}centos:7
    Stage: final

    %labels
        gitUrl ${params.gitUrl}
        gitCommit ${params.gitCommit}

    %files from devel
        /usr/local/bin /usr/local/bin


    %environment
        LC_ALL=en_US.utf-8
        LANG=en_US.utf-8
        PATH=/usr/local/bin:\\\$PATH

    EOF
    """
}

// onlyCondaRecipeCh = condaPackagesUnfilteredCh.mix(condaFilesUnfilteredCh)
condaPackagesUnfilteredCh.mix(condaFilesUnfilteredCh).groupTuple().into {
  onlyCondaRecipe4buildCondaCh; onlyCondaRecipe4buildMulticondaCh
}


singularityRecipeCh1
  .mix(singularityRecipeCh2)
  .mix(singularityRecipeCh5)
  .mix(singularityRecipeCh3)
  .mix(singularityRecipeCh4)
  .unique{ it[0] }
  .into {
    singularityAllRecipe4buildImagesCh; singularityAllRecipe4buildSingularityCh;
    singularityAllRecipe4buildDockerCh; singularityAllRecipe4buildPathCh
  }

process buildImages {
  tag "${key}"
  publishDir "${projectDir}/${params.publishDirSingularityImages}", overwrite: true, mode: 'copy'

  when:
    params.buildSingularityImages

  input:
    set val(key), file(singularityRecipe) from singularityAllRecipe4buildImagesCh
    file condaYml from condaRecipes.collect().ifEmpty([])
    file fileDep from fileDependencies.collect().ifEmpty([])
    file moduleDir from sourceCodeDirCh.collect().ifEmpty([])

  output:
    file("${key.toLowerCase()}.simg")

  script:
    """
    singularity build ${key.toLowerCase()}.simg ${singularityRecipe}
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
      withLabel:${key} { container = "\\\${params.geniac.singularityImagePath}/${key.toLowerCase()}.simg" }
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
    def checkProfileSingularity(path){
      if (new File(path).exists()){
        File directory = new File(path)
        def contents = []
        directory.eachFileRecurse (groovy.io.FileType.FILES) { file -> contents << file }
        if (!path?.trim() || contents == null || contents.size() == 0){
          println "   ### ERROR ###    The option '-profile singularity' requires the singularity images to be installed on your system. See \\`--singularityImagePath\\` for advanced usage."
          System.exit(-1)
        }
      }else{
        println "   ### ERROR ###    The option '-profile singularity' requires the singularity images to be installed on your system. See \\`--singularityImagePath\\` for advanced usage."
        System.exit(-1)
      }
    }

    singularity {
      enabled = true
      autoMounts = true
      runOptions = "\\\${params.geniac.containers.singularityRunOptions}"
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
      withLabel:${key} { container = "${key.toLowerCase()}" }
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
    """
    cat << EOF > "docker.config"
    docker {
      enabled = true
      runOptions = "\\\${params.geniac.containers.dockerRunOptions}"
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
 * Generate conda.config
 **/

process buildCondaConfig {
  tag "${key}"

  when:
    params.buildConfigFiles

  input:
    set val(key), val(singularityRecipe) from onlyCondaRecipe4buildCondaCh

  output:
    file("${key}CondaConfig.txt") into mergeCondaConfigCh

  script:
    """
    cat << EOF > "${key}CondaConfig.txt"
      withLabel:${key} { conda = "\\\${projectDir}/environment.yml" }
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
    echo -e "conda {\n  cacheDir = \\\"\\\${params.condaCacheDir}\\\"\n}\n" >> conda.config
    echo "process {"  >> conda.config
    echo "\n  beforeScript = \\\"export R_LIBS_USER=\\\\\\\"-\\\\\\\"; \\\"export R_PROFILE_USER=\\\\\\\"-\\\\\\\"; \\\"export R_ENVIRON_USER=\\\\\\\"-\\\\\\\"; export PYTHONNOUSERSITE=1\\\"\n" >> conda.config
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
    set val(key), val(condaDef) from onlyCondaRecipe4buildMulticondaCh.mix(condaExistingEnvsCh)

  output:
    file("${key}MulticondaConfig.txt") into mergeMulticondaConfigCh

  script:
    cplmt = condaDef == 'ENV' ? '.label' : ''
    """
    cat << EOF > "${key}MulticondaConfig.txt"
      withLabel:${key} { conda = "\\\${params.geniac.tools.${key}${cplmt}}" }
    EOF
    """
    // withLabel:${key} { conda = "\\\${params.geniac.tools.${key}}" }
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
    echo -e "conda {\n  cacheDir = \\\"\\\${params.condaCacheDir}\\\"\n}\n" >> multiconda.config
    echo "process {"  >> multiconda.config
    echo "\n  beforeScript = \\\"export R_LIBS_USER=\\\\\\\"-\\\\\\\"; \\\"export R_PROFILE_USER=\\\\\\\"-\\\\\\\"; \\\"export R_ENVIRON_USER=\\\\\\\"-\\\\\\\"; export PYTHONNOUSERSITE=1\\\"\n" >> multiconda.config
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
      withLabel:${key} { beforeScript = "export PATH=\\\${params.geniac.multiPath}/${key}/bin:\\\$PATH" }
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
        directory.eachFileRecurse (groovy.io.FileType.FILES) { file -> contents << file }
        if (!path?.trim() || contents == null || contents.size() == 0){
          println "   ### ERROR ###   The option '-profile multipath' requires the configuration of each tool path. See \\`--globalPath\\` for advanced usage."
          System.exit(-1)
        }
      }else{
        println "   ### ERROR ###   The option '-profile multipath' requires the configuration of each tool path. See \\`--globalPath\\` for advanced usage."
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
        directory.eachFileRecurse (groovy.io.FileType.FILES) { file -> contents << file }
        if (!path?.trim() || contents == null || contents.size() == 0){
          println "   ### ERROR ###   The option '-profile path' requires the configuration of each tool path. See \\`--globalPath\\` for advanced usage."
          System.exit(-1)
        }
      }else{
        println "   ### ERROR ###   The option '-profile path' requires the configuration of each tool path. See \\`--globalPath\\` for advanced usage."
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
