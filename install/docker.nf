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
Channel
  .from(params.geniac.tools)
  .flatMap {
    List<String> result = []
    for (Map.Entry<String, String> entry : it.entrySet()) {
      List<String> tab = entry.value.split()

      for (String s : tab) {
        result.add([entry.key, s.split('::')])
      }

      if (tab.size == 0) {
        result.add([entry.key, null])
      }
    }

    return result
  }.branch {
  condaFilesCh:
  (it[1] && it[1][0].endsWith('.yml'))
  return [it[0], file(it[1][0])]
  condaPackagesCh: true
  return it
}.set { condaForks }
(condaFilesCh, condaPackagesCh) = [condaForks.condaFilesCh, condaForks.condaPackagesCh]

Channel
  .fromPath("${projectDir}/recipes/docker/*.Dockerfile")
  .map {
    String optionalFile = null
    if (it.simpleName == 'r') {
      optionalFile = "${projectDir}/../preconfs/renv.lock"
    } else {
      optionalFile = 'EMPTY'
    }

    return [it.simpleName, it, optionalFile]
  }
  .set { dockerRecipeCh1 }


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
  }
  .set { sourceCodeCh }

/**
 * PROCESSES
 **/

/**
 * default recipes
 **/

process buildDefaultDockerRecipe {
  publishDir "${projectDir}/${params.publishDirDockerfiles}", overwrite: true, mode: 'copy'

  output:
    set val(key), file("${key}.Dockerfile"), val('EMPTY') into dockerRecipeCh2

  script:
    key = 'onlyLinux'
    """
    cat << EOF > ${key}.Dockerfile
    FROM centos:7

    LABEL gitUrl="${params.gitUrl}"
    LABEL gitCommit="${params.gitCommit}"

    RUN yum install -y which \\\\
    && yum clean all

    ENV LC_ALL en_US.utf-8
    ENV LANG en_US.utf-8
    EOF
    """
}



process buildDockerRecipeFromCondaFile {
  tag "${key}"
  publishDir "${projectDir}/${params.publishDirDockerfiles}", overwrite: true, mode: 'copy'

  input:
    set val(key), file(condaFile), val(yum), val(git) from condaFilesCh
      .groupTuple()
      .map { addYumAndGitToCondaCh(it) }

  output:
    set val(key), file("${key}.Dockerfile"), file(condaFile) into dockerRecipeCh3

  script:
    def cplmtGit = buildCplmtGit(git)
    def cplmtPath = buildCplmtPath(git)
    def yumPkgs = yum ?: ''
    yumPkgs = git ? "${yumPkgs} git" : yumPkgs

    """
    declare env_name=\$(head -1 ${condaFile} | cut -d' ' -f2)

    cat << EOF > ${key}.Dockerfile
    FROM conda/miniconda3-centos7

    LABEL gitUrl="${params.gitUrl}"
    LABEL gitCommit="${params.gitCommit}"

    # real path from projectDir: ${condaFile}
    ADD \$(basename ${condaFile}) /opt/\$(basename ${condaFile})

    RUN yum install -y which ${yumPkgs} ${cplmtGit} \\\\
    && yum clean all \\\\
    && conda env create -f /opt/\$(basename ${condaFile}) \\\\
    && echo "source activate \${env_name}" > ~/.bashrc \\\\
    && conda clean -a


    ENV PATH /usr/local/envs/\${env_name}/bin:${cplmtPath}\\\$PATH

    ENV LC_ALL en_US.utf-8
    ENV LANG en_US.utf-8
    EOF
    """
}

/**
 * Build Docker recipe from conda specifications in params.geniac.tools
 **/
process buildDockerRecipeFromCondaPackages {
  tag "${key}"
  publishDir "${projectDir}/${params.publishDirDockerfiles}", overwrite: true, mode: 'copy'


  input:
    set val(key), val(tools), val(yum), val(git) from condaPackagesCh
      .groupTuple()
      .map { addYumAndGitToCondaCh(it) }

  output:
    set val(key), file("${key}.Dockerfile"), val('EMPTY') into dockerRecipeCh4

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
    cat << EOF > ${key}.Dockerfile
    FROM conda/miniconda3-centos7

    LABEL gitUrl="${params.gitUrl}"
    LABEL gitCommit="${params.gitCommit}"

    RUN yum install -y which ${yumPkgs} ${cplmtGit} \\\\
    && yum clean all \\\\
    && conda create -y -n ${key}_env ${cplmtConda} \\\\
    && echo "source activate ${key}_env" > ~/.bashrc \\\\
    && conda clean -a


    ENV PATH /usr/local/envs/${key}_env/bin:${cplmtPath}\\\$PATH

    ENV LC_ALL en_US.utf-8
    ENV LANG en_US.utf-8
    EOF
    """
}


process buildDockerRecipeFromSourceCode {
  tag "${key}"
  publishDir "${projectDir}/${params.publishDirDockerfiles}", overwrite: true, mode: 'copy'

  input:
    set val(key), file(installFile) from sourceCodeCh

  output:
    set val(key), file("${key}.Dockerfile"), val('EMPTY') into dockerRecipeCh5

  script:
    """
    cat << EOF > ${key}.Dockerfile
    FROM centos:7
    
    LABEL gitUrl="${params.gitUrl}"
    LABEL gitCommit="${params.gitCommit}"

    RUN mkdir -p /opt/modules

    ADD modules/${installFile} /opt/modules
    ADD modules/${key}/ /opt/modules/${key}
      
    RUN yum install -y epel-release which gcc gcc-c++ make \\\\
    && cd /opt/modules \\\\
    && bash ${installFile} \\\\
    && rm -r /opt/modules

    ENV LC_ALL en_US.utf-8
    ENV LANG en_US.utf-8
    ENV PATH /usr/local/bin:\\\$PATH

    EOF
    """
}

onlyCondaRecipeCh = dockerRecipeCh3.mix(dockerRecipeCh4)
dockerAllRecipeCh = dockerRecipeCh1.mix(dockerRecipeCh2).mix(onlyCondaRecipeCh).mix(dockerRecipeCh5).dump(tag:'dockerRecipes')

process buildImages {
  tag "${key}"
  // publishDir "${projectDir}/${params.publishDirDockerImages}", overwrite: true, mode: 'copy'

  when:
    params.buildDockerImages

  input:
    set val(key), file(dockerRecipe), val(optionalPath) from dockerAllRecipeCh
    file condaYml from condaRecipes.collect().ifEmpty([])
    file fileDep from fileDependencies.collect().ifEmpty([])
    file moduleDir from sourceCodeDirCh.collect().ifEmpty([])

  script:
    excludemoduleDir = moduleDir == [] ? "--exclude='modules'" : ""
    """
    tar cvfh contextDir.tar ${excludemoduleDir} *
    mkdir contextDir
    tar xvf contextDir.tar --directory contextDir
    docker build  -f ${dockerRecipe} -t ${key.toLowerCase()} contextDir
    """
}

