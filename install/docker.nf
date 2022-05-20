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
condaExistingEnvs.into{ condaExistingEnvsCh; condaExistingRenvCh }
condaExistingRenvCh
  .filter {  it[0] =~/^renv.*/ }
  .set { condaFiles4DockerRecipesCh4Renv } // Channel for Renv environment
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
  .into{ sourceCodeCh1; sourceCodeCh2; sourceCodeCh3; sourceCodeCh4; sourceCodeCh5 }



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

    ENV R_LIBS_USER "-"
    ENV R_PROFILE_USER "-"
    ENV R_ENVIRON_USER "-"
    ENV PYTHONNOUSERSITE 1
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
      cplmtYum = """${params.yum} install -y ${yumPkgs} ${cplmtGit} \\\\
        && """
    }

    """
    declare env_name=\$(head -1 ${condaFile} | cut -d' ' -f2)

    cat << EOF > ${key}.Dockerfile
    FROM ${params.dockerRegistry}${params.dockerLinuxDistroConda}

    LABEL gitUrl="${params.gitUrl}"
    LABEL gitCommit="${params.gitCommit}"

    ENV R_LIBS_USER "-"
    ENV R_PROFILE_USER "-"
    ENV R_ENVIRON_USER "-"
    ENV PYTHONNOUSERSITE 1
    ENV PATH ${cplmtPath}\\\$PATH
    ENV LC_ALL en_US.utf-8
    ENV LANG en_US.utf-8
    ENV BASH_ENV /opt/etc/bashrc
    ${cplmtCmdEnv}

    # real path from projectDir: ${condaFile}
    ADD \$(basename ${condaFile}) /opt/\$(basename ${condaFile})

    RUN ${cplmtYum}${params.yum} clean all \\\\
    && conda env create -f /opt/\$(basename ${condaFile}) \\\\
    && echo -e "#! /bin/bash\\\\n\\\\n# script to activate the conda environment \${env_name}" > ~/.bashrc \\\\
    && echo "export PS1='Docker> '" >> ~/.bashrc \\\\
    && conda init bash \\\\
    && echo "conda activate \${env_name}" >> ~/.bashrc \\\\
    && mkdir -p /opt/etc \\\\
    && cp ~/.bashrc /opt/etc/bashrc \\\\
    && conda clean -a  ${cplmtCmdPost}

    ENV PATH /usr/local/conda/envs/\${env_name}/bin:\\\$PATH

    EOF
    """
}

process buildDockerRecipeFromCondaFile4Renv {
  tag "${key}"
  publishDir "${projectDir}/${params.publishDirDockerfiles}", overwrite: true, mode: 'copy'

  input:
    set val(key), file(condaFile), val(yum), val(git), val(cmdPost), val(cmdEnv) from condaFiles4DockerRecipesCh4Renv
      // to prevent conda recipes for specific fromSourceCode cases
      .join(sourceCodeCh5, remainder: true)
      .filter{ it[1] && !it[2] }
      .map{ [it[0], it[1]] }
      .groupTuple()
      .map{ addYumAndGitAndCmdConfs(it) }

  output:
    set val(key), file("${key}.Dockerfile") into dockerRecipeCh6

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

    cat << EOF > ${key}.Dockerfile
    FROM ${params.dockerRegistry}${params.dockerLinuxDistroConda}

    LABEL gitUrl="${params.gitUrl}"
    LABEL gitCommit="${params.gitCommit}"

    ENV R_LIBS_USER "-"
    ENV R_PROFILE_USER "-"
    ENV R_ENVIRON_USER "-"
    ENV PYTHONNOUSERSITE 1
    ENV PATH ${cplmtPath}\\\$PATH
    ENV LC_ALL en_US.utf-8
    ENV LANG en_US.utf-8
    ENV BASH_ENV /opt/etc/bashrc
    ENV PKG_CONFIG_PATH /usr/local/lib/pkgconfig
    ENV PKG_LIBS -liconv
    ${cplmtCmdEnv}

    ARG R_MIRROR=https://cloud.r-project.org
    ARG R_ENV_DIR=/opt/renv
    ARG CACHE=TRUE
    ARG CACHE_DIR=/opt/renv_cache

    # real path from projectDir: ${renvYml}
    ADD conda/\$(basename ${renvYml}) /opt/\$(basename ${renvYml})
    ADD dependencies/${key}/renv.lock /opt/renv/renv.lock

    RUN ${cplmtYum}${params.yum} clean all \\\\
    && conda env create -f /opt/\$(basename ${renvYml}) \\\\
    && mkdir -p /opt/etc \\\\
    && echo -e "#! /bin/bash\\\\n\\\\n# script to activate the conda environment \${env_name}" > ~/.bashrc \\\\
    && echo "export PS1='Docker> '" >> ~/.bashrc \\\\
    && conda init bash \\\\
    && echo "conda activate \${env_name}" >> ~/.bashrc \\\\
    && mkdir -p /opt/etc \\\\
    && cp ~/.bashrc /opt/etc/bashrc \\\\
    && conda clean -a ${cplmtCmdPost}
    RUN source /opt/etc/bashrc \\\\
    && R -q -e "options(repos = \\\\"\\\${R_MIRROR}\\\\") ; install.packages(\\\\"renv\\\\") ; options(renv.config.install.staged=FALSE, renv.settings.use.cache=FALSE) ; install.packages(\\\\"BiocManager\\\\"); BiocManager::install(version=\\\\"${bioc}\\\\", ask=FALSE) ; renv::restore(lockfile = \\\\"\\\${R_ENV_DIR}/renv.lock\\\\")"

    ENV PATH /usr/local/conda/envs/\${env_name}/bin:\\\$PATH

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
      cplmtYum = """${params.yum} install -y ${yumPkgs} ${cplmtGit} \\\\
    && """
    }

    """
    cat << EOF > ${key}.Dockerfile
    FROM ${params.dockerRegistry}${params.dockerLinuxDistroConda}

    LABEL gitUrl="${params.gitUrl}"
    LABEL gitCommit="${params.gitCommit}"

    ENV R_LIBS_USER "-"
    ENV R_PROFILE_USER "-"
    ENV R_ENVIRON_USER "-"
    ENV PYTHONNOUSERSITE 1
    ENV PATH ${cplmtPath}\\\$PATH
    ENV LC_ALL en_US.utf-8
    ENV LANG en_US.utf-8
    ENV BASH_ENV /opt/etc/bashrc
    ${cplmtCmdEnv}

    RUN ${cplmtYum}${params.yum} clean all \\\\
    && conda create -y -n ${key}_env \\\\
    && conda install -y ${condaChannelsOption} -n ${key}_env ${condaPackagesOption} \\\\
    && conda clean -a ${cplmtCmdPost} \\\\
    && echo -e "#! /bin/bash\\\\n\\\\n# script to activate the conda environment ${key}_env" > ~/.bashrc \\\\
    && echo "export PS1='Docker> '" >> ~/.bashrc \\\\
    && conda init bash \\\\
    && echo "conda activate ${key}_env" >> ~/.bashrc \\\\
    && mkdir -p /opt/etc \\\\
    && cp ~/.bashrc /opt/etc/bashrc \\\\
    && conda clean -a ${cplmtCmdPost}
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
      cplmtYum = """${params.yum} install -y ${yumPkgs} ${cplmtGit} \\\\
        && """
    }

    """

    image_name=\$(grep -q conda ${cmdPost} && echo "${params.dockerLinuxDistroConda}" || echo "${params.dockerLinuxDistro}")

    cat << EOF > ${key}.Dockerfile
    FROM ${params.dockerRegistry}${params.dockerLinuxDistroSdk} AS devel

    RUN mkdir -p /opt/modules

    ADD ${key}/ /opt/modules/${key}
    
    RUN ${cplmtYum}cd /opt/modules \\\\
    && mkdir build && cd build || exit \\\\
    && cmake3 ../${key} -DCMAKE_INSTALL_PREFIX=/usr/local/bin/${key} \\\\
    && make && make install ${cplmtCmdPost}

    FROM ${params.dockerRegistry}\${image_name}

    LABEL gitUrl="${params.gitUrl}"
    LABEL gitCommit="${params.gitCommit}"

    COPY --from=devel /usr/local/bin/${key}/ /usr/local/bin/${key}/

    RUN ${cplmtYum}${params.yum} install -y glibc-devel libstdc++-devel

    ENV R_LIBS_USER "-"
    ENV R_PROFILE_USER "-"
    ENV R_ENVIRON_USER "-"
    ENV PYTHONNOUSERSITE 1
    ENV LC_ALL en_US.utf-8
    ENV LANG en_US.utf-8
    ENV PATH /usr/local/bin/${key}:${cplmtPath}\\\$PATH
    ${cplmtCmdEnv}

    EOF
    """
}

// onlyCondaRecipeCh = condaPackagesUnfilteredCh.mix(condaFilesUnfilteredCh)
condaPackagesUnfilteredCh.mix(condaFilesUnfilteredCh).groupTuple().into {
  onlyCondaRecipe4buildCondaCh; onlyCondaRecipe4buildMulticondaCh
}


dockerRecipeCh6
  .concat(dockerRecipeCh5)
  .concat(dockerRecipeCh4)
  .concat(dockerRecipeCh3)
  .concat(dockerRecipeCh2)
  .concat(dockerRecipeCh1) // DONT'T MOVE: this channel must be the last one to be concatenated
  .groupTuple()
  .map{ key, tab -> [key, tab[0]] }
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
    if (key ==~ /^renv.*/ ) {
      contextDir = "${projectDir}/recipes"
    } else
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
    ${params.dockerCmd} build  -f ${dockerRecipe} -t ${key.toLowerCase()} ${contextDir}
    """
}

