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

def addYumAndGitAndCmdConfs(List input) {
  List<String> gitList = []
  LinkedHashMap gitConf = params.geniac.containers.git ?: [:]
  LinkedHashMap yumConf = params.geniac.containers.yum ?: [:]
  LinkedHashMap cmdPostConf = params.geniac.containers.cmd.post ?: [:]
  LinkedHashMap cmdEnvConf = params.geniac.containers.cmd.envCustom ?: [:]
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

(condaExistingEnvsCh, condaFilesCh, condaPackagesCh) = [condaForks.condaExistingEnvsCh, condaForks.condaFilesCh, condaForks.condaPackagesCh]
condaPackagesCh.into{ condaPackages4DockerRecipesCh; condaPackages4CondaEnvCh; condaPackagesUnfilteredCh }
condaFilesCh.into{ condaFiles4DockerRecipesCh; condaFilesForCondaDepCh; condaFilesUnfilteredCh }



Channel
  .fromPath("${projectDir}/recipes/docker/*.Dockerfile")
  .map{ [it.simpleName, it] }
  .set{ dockerRecipeCh1 }

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
  .into{ sourceCodeCh1; sourceCodeCh2; sourceCodeCh3; sourceCodeCh4 }



/**
 * PROCESSES
 **/

/**
 * default recipes
 **/

process buildDefaultDockerRecipe {
  publishDir "${projectDir}/${params.publishDirDockerfiles}", overwrite: true, mode: 'copy'

  output:
    set val(key), file("${key}.Dockerfile") into dockerRecipeCh2

  script:
    key = 'onlyLinux'
    """
    cat << EOF > ${key}.Dockerfile
    FROM ${params.dockerRegistry}${params.dockerLinuxDistro}

    LABEL gitUrl="${params.gitUrl}"
    LABEL gitCommit="${params.gitCommit}"

    ENV LC_ALL en_US.utf-8
    ENV LANG en_US.utf-8
    EOF
    """
}

process buildDockerRecipeFromCondaFile {
  tag "${key}"
  publishDir "${projectDir}/${params.publishDirDockerfiles}", overwrite: true, mode: 'copy'

  input:
    set val(key), file(condaFile), val(yum), val(git), val(cmdPost), val(cmdEnv) from condaFiles4DockerRecipesCh

      // to prevent conda recipes for specific fromSourceCode cases
      .join(sourceCodeCh1, remainder: true)
      .filter{ it[1] && !it[2] }

      .map{ [it[0], it[1]] }
      .groupTuple()
      .map{ addYumAndGitAndCmdConfs(it) }

  output:
    set val(key), file("${key}.Dockerfile") into dockerRecipeCh3

  script:
    def cplmtGit = buildCplmtGit(git)
    def cplmtPath = buildCplmtPath(git)
    def cplmtCmdPost = cmdPost ? '\\\\\n    && ' + cmdPost.join(' \\\\\n    && '): ''
    def cplmtCmdEnv = cmdEnv ? 'ENV ' + cmdEnv.join('\n    ENV ').replace('=', ' '): ''
    def yumPkgs = yum ?: ''
    yumPkgs = git ? "${yumPkgs} git" : yumPkgs

    def cplmtYum = ''
    if ("${yumPkgs}${cplmtGit}".length()> 0 ) {
      cplmtYum = """yum install -y ${yumPkgs} ${cplmtGit} \\\\
        && """
    }

    """
    declare env_name=\$(head -1 ${condaFile} | cut -d' ' -f2)

    cat << EOF > ${key}.Dockerfile
    FROM ${params.dockerRegistry}${params.dockerLinuxDistroConda}

    LABEL gitUrl="${params.gitUrl}"
    LABEL gitCommit="${params.gitCommit}"

    ENV PATH /usr/local/conda/envs/\${env_name}/bin:${cplmtPath}\\\$PATH
    ENV LC_ALL en_US.utf-8
    ENV LANG en_US.utf-8
    ${cplmtCmdEnv}

    # real path from projectDir: ${condaFile}
    ADD \$(basename ${condaFile}) /opt/\$(basename ${condaFile})

    RUN ${cplmtYum}yum clean all \\\\
    && conda env create -f /opt/\$(basename ${condaFile}) \\\\
    && echo "conda activate \${env_name}" > ~/.bashrc \\\\
    && conda clean -a  ${cplmtCmdPost}


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
    set val(key), val(tools), val(yum), val(git), val(cmdPost), val(cmdEnv) from condaPackages4DockerRecipesCh

      // to prevent conda recipes for specific fromSourceCode cases
      .join(sourceCodeCh2, remainder: true)
      .filter{ it[1] && !it[2] }

      .map{ [it[0], it[1]] }
      .groupTuple()
      .map{ addYumAndGitAndCmdConfs(it) }

  output:
    set val(key), file("${key}.Dockerfile") into dockerRecipeCh4

  script:
    def cplmtGit = buildCplmtGit(git)
    def cplmtPath = buildCplmtPath(git)
    def cplmtCmdPost = cmdPost ? '\\\\\n    && ' + cmdPost.join(' \\\\\n    && '): ''
    def cplmtCmdEnv = cmdEnv ? 'ENV ' + cmdEnv.join('\n    ENV ').replace('=', ' '): ''
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
      cplmtYum = """yum install -y ${yumPkgs} ${cplmtGit} \\\\
    && """
    }

    """
    cat << EOF > ${key}.Dockerfile
    FROM ${params.dockerRegistry}${params.dockerLinuxDistroConda}

    LABEL gitUrl="${params.gitUrl}"
    LABEL gitCommit="${params.gitCommit}"

    ENV PATH /usr/local/conda/envs/${key}_env/bin:${cplmtPath}\\\$PATH
    ENV LC_ALL en_US.utf-8
    ENV LANG en_US.utf-8
    ${cplmtCmdEnv}

    RUN ${cplmtYum}yum clean all \\\\
    && conda create -y -n ${key}_env \\\\
    && conda install -y ${condaChannelsOption} -n ${key}_env ${condaPackagesOption} \\\\
    && conda clean -a ${cplmtCmdPost} \\\\
    && echo "conda activate ${key}_env" > ~/.bashrc
    EOF
    """
}


process buildDockerRecipeFromSourceCode {
  tag "${key}"
  publishDir "${projectDir}/${params.publishDirDockerfiles}", overwrite: true, mode: 'copy'

  input:
    set val(key), file(dir), val(yum), val(git), val(cmdPost), val(cmdEnv) from sourceCodeCh3.map{ addYumAndGitAndCmdConfs(it) }

  output:
    set val(key), file("${key}.Dockerfile") into dockerRecipeCh5

  script:
    def cplmtGit = buildCplmtGit(git)
    def cplmtPath = buildCplmtPath(git)
    def cplmtCmdPost = cmdPost ? '\\\\\n    && ' + cmdPost.join(' \\\\\n    && '): ''
    def cplmtCmdEnv = cmdEnv ? 'ENV ' + cmdEnv.join('\n    ENV ').replace('=', ' '): ''
    def yumPkgs = yum ?: ''
    yumPkgs = git ? "${yumPkgs} git" : yumPkgs


    def cplmtYum = ''
    if ("${yumPkgs}${cplmtGit}".length()> 0 ) {
      cplmtYum = """yum install -y ${yumPkgs} ${cplmtGit} \\\\
        && """
    }

    """

    cat << EOF > ${key}.Dockerfile
    FROM ${params.dockerRegistry}${params.dockerLinuxDistroSdk}
    
    LABEL gitUrl="${params.gitUrl}"
    LABEL gitCommit="${params.gitCommit}"

    RUN mkdir -p /opt/modules

    ADD ${key}/ /opt/modules/${key}
    
    RUN ${cplmtYum}cd /opt/modules \\\\
    && mkdir build && cd build || exit \\\\
    && cmake3 ../${key} -DCMAKE_INSTALL_PREFIX=/usr/local/bin \\\\
    && make && make install ${cplmtCmdPost}

    ENV LC_ALL en_US.utf-8
    ENV LANG en_US.utf-8
    ENV PATH /usr/local/bin:${cplmtPath}\\\$PATH
    ${cplmtCmdEnv}

    EOF
    """
}

// onlyCondaRecipeCh = condaPackagesUnfilteredCh.mix(condaFilesUnfilteredCh)
condaPackagesUnfilteredCh.mix(condaFilesUnfilteredCh).groupTuple().into {
  onlyCondaRecipe4buildCondaCh; onlyCondaRecipe4buildMulticondaCh
}


dockerRecipeCh1
  .mix(dockerRecipeCh2)
  .mix(dockerRecipeCh5)
  .mix(dockerRecipeCh3)
  .mix(dockerRecipeCh4)
  .unique{ it[0] }
  .into {
    dockerAllRecipe4buildImagesCh; dockerAllRecipe4buildDockerCh;
    dockerAllRecipe4buildPathCh
  }

process buildImages {
  maxForks 1
  tag "${key}"
  // publishDir "${projectDir}/${params.publishDirDockerImages}", overwrite: true, mode: 'copy'

  when:
    params.buildDockerImages

  input:
    set val(key), file(dockerRecipe), file(fileDepDir), file(condaRecipe), file(sourceCodeDir) from dockerAllRecipe4buildImagesCh
      .join(fileDependencies, remainder: true)
      .join(condaRecipes, remainder: true)
      .join(sourceCodeCh4, remainder: true)
      .filter{ it[1] }


  script:
    String contextDir
    if (fileDepDir.name.toString() == key) {
      contextDir = "${projectDir}/recipes/dependencies"
    } else
    if (condaRecipe.name.toString().replace('.yml', '') == key) {
        contextDir = "${projectDir}/recipes/conda"
    } else
    if (sourceCodeDir.name.toString() == key) {
        contextDir = "${projectDir}/modules/fromSource"
    } else {
      contextDir = "."
    }
    """
    docker build  -f ${dockerRecipe} -t ${key.toLowerCase()} ${contextDir}
    """
}

