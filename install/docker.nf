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

// Channel for Renv environment
condaExistingEnvsCh
  .filter {  it[0] =~/^renv.*/ }
  .set { condaFiles4Renv }

// DOCKER RECIPES
Channel
  .fromPath("${projectDir}/recipes/docker/*.Dockerfile")
  .map{ [it.simpleName, it] }
  .set{ dockerRecipesCh }

// CONDA RECIPES
Channel
  .fromPath("${projectDir}/recipes/conda/*.yml")
  .map{ [it.simpleName, it] }
  .set{ condaRecipesCh }

// DEPENDENCIES
Channel
  .fromPath("${projectDir}/recipes/dependencies/*", type: 'dir')
  .map{ [it.name, it] }
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
 * docker profile
 *
 * Geniac documentation:
 *   - https://geniac.readthedocs.io/en/latest/run.html#run-profile-docker
 *
 **/

//////////////////////
// STEP - ONLYLINUX //
//////////////////////

// This process creates the container recipe for the onlyLinux label.
// Geniac documentation:
//   - https://geniac.readthedocs.io/en/latest/process.html#process-unix
process buildDefaultDockerRecipe {
  publishDir "${projectDir}/${params.publishDirDockerfiles}", overwrite: true, mode: 'copy'

  output:
    tuple val(key), path("${key}.Dockerfile"), emit: dockerRecipes
    tuple val(key), path("${key}.sha256sum"), emit: sha256sum

  script:
    key = 'onlyLinux'
    """
    # write recipe
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
process buildDockerRecipeFromCondaPackages {
  tag "${key}"
  publishDir "${projectDir}/${params.publishDirDockerfiles}", overwrite: true, mode: 'copy'

  input:
    tuple val(key), val(tools), val(yum), val(git), val(cmdPost), val(cmdEnv)

  output:
    tuple val(key), path("${key}.Dockerfile"), emit: dockerRecipes
    tuple val(key), path("${key}.sha256sum"), emit: sha256sum

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
      cplmtYum = """${params.yum} install ${params.yumOptions} -y ${yumPkgs} ${cplmtGit} \\\\
    && """
    }

    """
    # write the recipe
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
    && CONDA_ROOT=\\\$(conda info --system | grep CONDA_ROOT | awk '{print \\\$2}') \\\\
    && micromamba install --root-prefix \\\${CONDA_ROOT} -y ${condaChannelsOption} -n ${key}_env ${condaPackagesOption} \\\\
    && echo -e "#! /bin/bash\\\\n\\\\n# script to activate the conda environment ${key}_env" > ~/.bashrc \\\\
    && echo "export PS1='Docker> '" >> ~/.bashrc \\\\
    && conda init bash \\\\
    && echo "conda activate ${key}_env" >> ~/.bashrc \\\\
    && mkdir -p /opt/etc \\\\
    && cp ~/.bashrc /opt/etc/bashrc \\\\
    && conda clean -y -a \\\\
    && micromamba clean -y -a ${cplmtCmdPost}
    EOF

    # compute hash digest of the recipe using
    #  - only the recipe file without the labels
    cat ${key}.Dockerfile | grep -v gitCommit | grep -v gitUrl | sha256sum  | awk '{print \$1}' | sed -e 's/\$/ ${key}/g' > ${key}.sha256sum
    """
}

// This process creates the container recipes for each tool defined as a conda env from a yml file
// Geniac documentation:
//   - https://geniac.readthedocs.io/en/latest/process.html#process-custom-conda
process buildDockerRecipeFromCondaFile {
  tag "${key}"
  publishDir "${projectDir}/${params.publishDirDockerfiles}", overwrite: true, mode: 'copy'

  input:
    tuple val(key), path(condaFile), val(yum), val(git), val(cmdPost), val(cmdEnv)

  output:
    tuple val(key), path("${key}.Dockerfile"), emit: dockerRecipes
    tuple val(key), path("${key}.sha256sum"), emit: sha256sum

  script:
    def cplmtGit = buildCplmtGit(git)
    def cplmtPath = buildCplmtPath(git)
    def cplmtCmdPost = cmdPost ? '\\\\\n    && ' + cmdPost.join(' \\\\\n    && '): ''
    def cplmtCmdEnv = cmdEnv ? 'ENV ' + cmdEnv.join('\n    ENV ').replace('=', ' '): ''
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
    && CONDA_ROOT=\\\$(conda info --system | grep CONDA_ROOT | awk '{print \\\$2}') \\\\
    && micromamba env create --root-prefix \\\${CONDA_ROOT} -f /opt/\$(basename ${condaFile}) \\\\
    && echo -e "#! /bin/bash\\\\n\\\\n# script to activate the conda environment \${env_name}" > ~/.bashrc \\\\
    && echo "export PS1='Docker> '" >> ~/.bashrc \\\\
    && conda init bash \\\\
    && echo "conda activate \${env_name}" >> ~/.bashrc \\\\
    && mkdir -p /opt/etc \\\\
    && cp ~/.bashrc /opt/etc/bashrc \\\\
    && conda clean -y -a \\\\
    && micromamba clean -y -a ${cplmtCmdPost}

    ENV PATH /usr/local/conda/envs/\${env_name}/bin:\\\$PATH

    EOF
    # compute hash digest of the recipe using:
    #   - the recipe file without the labels / comments
    #   - the conda yml
    cat ${key}.Dockerfile ${condaFile} | grep -v gitCommit | grep -v gitUrl | grep -v "real path from projectDir" | sha256sum | awk '{print \$1}' | sed -e 's/\$/ ${key}/g' > ${key}.sha256sum
    """
}

// This process creates the container recipes for each tool defined as a Renv.
// Geniac documentation:
//   - https://geniac.readthedocs.io/en/latest/process.html#r-packages-using-renv
process buildDockerRecipeFromCondaFile4Renv {
  tag "${key}"
  publishDir "${projectDir}/${params.publishDirDockerfiles}", overwrite: true, mode: 'copy'

  input:
    tuple val(key), val(condaEnv), val(yum), val(git), val(cmdPost), val(cmdEnv), path(dependencies)

  output:
    tuple val(key), path("${key}.Dockerfile"), emit: dockerRecipes
    tuple val(key), path("${key}.sha256sum"), emit: sha256sum

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
      cplmtYum = """${params.yum} install ${params.yumOptions} -y ${yumPkgs} ${cplmtGit} \\\\
        && """
    }

    """
    declare env_name=\$(head -1 ${renvYml} | cut -d' ' -f2)

    # write the recipe
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
    && CONDA_ROOT=\\\$(conda info --system | grep CONDA_ROOT | awk '{print \\\$2}') \\\\
    && micromamba env create --root-prefix \\\${CONDA_ROOT} -f /opt/\$(basename ${renvYml}) \\\\
    && mkdir -p /opt/etc \\\\
    && echo -e "#! /bin/bash\\\\n\\\\n# script to activate the conda environment \${env_name}" > ~/.bashrc \\\\
    && echo "export PS1='Docker> '" >> ~/.bashrc \\\\
    && conda init bash \\\\
    && echo "conda activate \${env_name}" >> ~/.bashrc \\\\
    && mkdir -p /opt/etc \\\\
    && cp ~/.bashrc /opt/etc/bashrc \\\\
    && conda clean -y -a \\\\
    && micromamba clean -y -a ${cplmtCmdPost}
    RUN source /opt/etc/bashrc \\\\
    && R -q -e "options(repos = \\\\"\\\${R_MIRROR}\\\\") ; install.packages(\\\\"renv\\\\") ; options(renv.config.install.staged=FALSE, renv.settings.use.cache=FALSE) ; install.packages(\\\\"BiocManager\\\\"); BiocManager::install(version=\\\\"${bioc}\\\\", ask=FALSE) ; renv::restore(lockfile = \\\\"\\\${R_ENV_DIR}/renv.lock\\\\")"

    ENV PATH /usr/local/conda/envs/\${env_name}/bin:\\\$PATH

    EOF

    # compute hash digest of the recipe using:
    #   - the recipe file without the labels
    #   - the conda yml
    #   - the renv.lock
    cat ${key}.Dockerfile ${renvYml} ${key}/renv.lock | grep -v gitCommit | grep -v gitUrl | grep -v "real path from projectDir" | sha256sum | awk '{print \$1}' | sed -e 's/\$/ ${key}/g' > ${key}.sha256sum
    """
}

////////////////////////
// STEP - SOURCE CODE //
////////////////////////

// This process creates the container recipes for each tool installed from source code.
// Geniac documentation.
//   - https://geniac.readthedocs.io/en/latest/process.html#install-from-source-code
process buildDockerRecipeFromSourceCode {
  tag "${key}"
  publishDir "${projectDir}/${params.publishDirDockerfiles}", overwrite: true, mode: 'copy'

  input:
    tuple val(key), file(dir), val(yum), val(git), val(cmdPost), val(cmdEnv)

  output:
    tuple val(key), file("${key}.Dockerfile"), emit: dockerRecipes
    tuple val(key), path("${key}.sha256sum"), emit: sha256sum

  script:
    def cplmtGit = buildCplmtGit(git)
    def cplmtPath = buildCplmtPath(git)
    def cplmtCmdPost = cmdPost ? '\\\\\n    && ' + cmdPost.join(' \\\\\n    && '): ''
    def cplmtCmdEnv = cmdEnv ? 'ENV ' + cmdEnv.join('\n    ENV ').replace('=', ' '): ''
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

    RUN ${cplmtYum}${params.yum} install ${params.yumOptions} -y glibc-devel libstdc++-devel

    ENV R_LIBS_USER "-"
    ENV R_PROFILE_USER "-"
    ENV R_ENVIRON_USER "-"
    ENV PYTHONNOUSERSITE 1
    ENV LC_ALL en_US.utf-8
    ENV LANG en_US.utf-8
    ENV PATH /usr/local/bin/${key}:${cplmtPath}\\\$PATH
    ${cplmtCmdEnv}

    EOF

    # compute hash digest of the recipe using:
    #   - the recipe file without the labels / comments
    #   - the source code
    tar --mtime='1970-01-01' -cf ${key}.tar -C ${key} --sort=name --group=0 --owner=0 --numeric-owner --mode=777 .
    grep -v gitCommit ${key}.Dockerfile | grep -v gitUrl > ${key}-nolabels.def 
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
  // publishDir "${projectDir}/${params.publishDirDockerImages}", overwrite: true, mode: 'copy'

  when:
    params.buildDockerImages

  input:
    tuple val(key), file(dockerRecipe), file(fileDepDir), file(condaRecipe), file(sourceCodeDir) // from dockerAllRecipe4buildImagesCh
    //  .join(fileDependencies, remainder: true)
    //  .join(condaRecipes, remainder: true)
    //  .join(sourceCodeCh4, remainder: true)
    //  .filter{ it[1] }


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

  stub:
    """
    echo "build docker image for the tool ${key}"
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
  publishDir "${projectDir}/${params.publishDirDockerfiles}", overwrite: true, mode: 'copy'

  input:
    tuple val(key), path(recipe), path(fileDependencies)

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
  publishDir "${projectDir}/${params.publishDirDockerfiles}", overwrite: true, mode: 'copy'

  input:
    path("*")

  output:
    path("sha256sum")

  script:
    """
    cat *.sha256sum > sha256sum
    """
}

workflow {
  main:

  ///////////////////////////
  // STEP - CREATE RECIPES //
  ///////////////////////////

  // Create the onlyLinux container recipe
  buildDefaultDockerRecipe()
  
  // Create the container recipes for each tool defined with a list of packages in geniac.config
  buildDockerRecipeFromCondaPackages(
    condaPackagesCh
      // to prevent conda recipes for specific fromSourceCode cases
      .join(sourceCodeCh, remainder: true)
      .filter{ it[1] && !it[2] }
      .map{ [it[0], it[1]] }
      .groupTuple()
      .map{ addYumAndGitAndCmdConfs(it) }
  )

  // Create the container recipes for each tool defined as a conda env from a yml file
  buildDockerRecipeFromCondaFile(
    condaFilesCh
      // to prevent conda recipes for specific fromSourceCode cases
      .join(sourceCodeCh, remainder: true)
      .filter{ it[1] && !it[2] }
      .map{ [it[0], it[1]] }
      .groupTuple()
      .map{ addYumAndGitAndCmdConfs(it) }
  )

  // Create the container recipes for each tool defined as a Renv
  buildDockerRecipeFromCondaFile4Renv(
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
  buildDockerRecipeFromSourceCode(
    sourceCodeCh
      .map{ addYumAndGitAndCmdConfs(it) }
  )

  // SHA256SUM
  sha256sumManualRecipes(
    dockerRecipesCh
      .combine(
        fileDependenciesCh
          .map{ it[1] }
          .collect()
          .toList()
      )
  )

  buildDockerRecipeFromCondaFile4Renv.out.sha256sum
    .concat(buildDockerRecipeFromSourceCode.out.sha256sum)
    .concat(buildDockerRecipeFromCondaPackages.out.sha256sum)
    .concat(buildDockerRecipeFromCondaFile.out.sha256sum)
    .concat(buildDefaultDockerRecipe.out.sha256sum)
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
  buildDockerRecipeFromCondaFile4Renv.out.dockerRecipes
    .concat(buildDockerRecipeFromSourceCode.out.dockerRecipes)
    .concat(buildDockerRecipeFromCondaPackages.out.dockerRecipes)
    .concat(buildDockerRecipeFromCondaFile.out.dockerRecipes)
    .concat(buildDefaultDockerRecipe.out.dockerRecipes)
    .concat(dockerRecipesCh)
    // je pense que les deux lignes de dessous ne servent à rien
    //.groupTuple()
    //.map{ key, tab -> [key, tab[0]] }
    .set { dockerAllRecipes }

  // Select the list of tools if containerList has been provided
  if (params.containerList != null) {
    dockerAllRecipes
      .join(containerListCh)
      .set{ dockerAllRecipes }
  }

  // Create all the containers
  buildImages(
    dockerAllRecipes
      .join(fileDependenciesCh, remainder: true)
      .join(condaRecipesCh, remainder: true)
      .join(sourceCodeCh, remainder: true)
      .filter{ it[1] }
  )

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

