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

/*
==================================
           INCLUDE
==================================
*/

include { buildCplmtGit } from '../../../lib/functions'
include { buildCplmtPath } from '../../../lib/functions'
include { addYumAndGitAndCmdConfs } from '../../../lib/functions'

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
    tuple val(key), path("${key}-4fromRegistry.def"), emit: singularityRecipes4fromRegistry
    tuple val(key), path("${key}.sha256sum"), emit: sha256sum

  script:
    key = 'onlyLinux'
    """
    # write recipe
    echo "Test build from registry"
    echo "The variable is ${params.buildSingularityImagesFromRegistry}"
    cat << EOF > ${key}.def
    Bootstrap: docker
    From: ${params.dockerRegistry}${params.dockerLinuxDistro}

    %labels
        gitUrl ${params.gitUrl}
        gitCommit ${params.gitCommit}

    %environment
    EOF

    cat ${projectDir}/assets/def.env >> ${key}.def
    cp ${key}.def ${key}-4fromRegistry.def
    
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
    tuple val(key), path("${key}-4fromRegistry.def"), emit: singularityRecipes4fromRegistry
    tuple val(key), path("${key}.sha256sum"), emit: sha256sum

  script:
    def cplmtGit = buildCplmtGit(git, '    ')
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
    EOF

    cat ${projectDir}/assets/def.env >> ${key}.def

    cat << EOF >> ${key}.def
        export PATH=${cplmtPath}\\\$PATH
        source /opt/etc/bashrc
        ${cplmtCmdEnv}
    EOF

    cp ${key}.def ${key}-4fromRegistry.def

    cat << EOF >> ${key}.def
    %post
        ${cplmtYum}${params.yum} clean all \\\\
        && conda create --no-default-packages -y -n ${key}_env \\\\
        && CONDA_ROOT=\\\$(conda info --system | grep CONDA_ROOT | awk '{print \\\$2}') \\\\
        && micromamba install --override-channels --root-prefix \\\${CONDA_ROOT} -y ${condaChannelsOption} -n ${key}_env ${condaPackagesOption} \\\\
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
    tuple val(key), path("${key}-4fromRegistry.def"), emit: singularityRecipes4fromRegistry
    tuple val(key), path("${key}.sha256sum"), emit: sha256sum

  script:
    def cplmtGit = buildCplmtGit(git, '    ')
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
    EOF

    cat ${projectDir}/assets/def.env >> ${key}.def

    cat << EOF >> ${key}.def
        export PATH=${cplmtPath}\\\$PATH
        source /opt/etc/bashrc
        ${cplmtCmdEnv}
    EOF

    cp ${key}.def ${key}-4fromRegistry.def

    # real path from projectDir: ${condaFile}
    cat << EOF >> ${key}.def
    %files
        \$(basename ${condaFile}) /opt/\$(basename ${condaFile})

    %post
        ${cplmtYum}${params.yum} clean all \\\\
        && CONDA_ROOT=\\\$(conda info --system | grep CONDA_ROOT | awk '{print \\\$2}') \\\\
        && micromamba env create --override-channels --root-prefix \\\${CONDA_ROOT} -f /opt/\$(basename ${condaFile}) \\\\
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
    tuple val(key), path("${key}-4fromRegistry.def"), emit: singularityRecipes4fromRegistry
    tuple val(key), path("${key}.sha256sum"), emit: sha256sum

  script:
    def renvYml = params.geniac.tools.get(key).get('yml')
    def bioc = params.geniac.tools.get(key).get('bioc')
    def cplmtGit = buildCplmtGit(git, '    ')
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
    EOF

    cat ${projectDir}/assets/def.env >> ${key}.def

    cat << EOF >> ${key}.def
        export PATH=${cplmtPath}\\\$PATH
        source /opt/etc/bashrc
        ${cplmtCmdEnv}
    EOF

    cp ${key}.def ${key}-4fromRegistry.def

    cat << EOF >> ${key}.def
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
        && micromamba env create --override-channels --root-prefix \\\${CONDA_ROOT} -f /opt/\$(basename ${renvYml}) \\\\
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
    tuple val(key), path("${key}-4fromRegistry.def"), emit: singularityRecipes4fromRegistry
    tuple val(key), path("${key}.sha256sum"), emit: sha256sum

  script:
    def cplmtGit = buildCplmtGit(git, '    ')
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
    cat << EOF > ${key}-stageDevel.def
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
    EOF

    cat << EOF >> ${key}-stageFinal.def
    Bootstrap: docker
    From: ${params.dockerRegistry}\${image_name}
    Stage: final

    %labels
        gitUrl ${params.gitUrl}
        gitCommit ${params.gitCommit}

    %environment
    EOF

    cat ${projectDir}/assets/def.env >> ${key}-stageFinal.def

    cat << EOF >> ${key}-stageFinal.def
        export PATH=/usr/local/bin/${key}:${cplmtPath}\\\$PATH
        ${cplmtCmdEnv}
    EOF

    cp ${key}-stageFinal.def ${key}-4fromRegistry.def

    cat << EOF >> ${key}-stageFinal.def
    %files from devel
        /usr/local/bin/${key}/ /usr/local/bin/

    %post
        ${cplmtYum}${params.yum} install ${params.yumOptions} -y glibc-devel libstdc++-devel

    EOF

    cat ${key}-stageDevel.def ${key}-stageFinal.def > ${key}.def

    # compute hash digest of the recipe using:
    #   - the recipe file without the labels / comments
    #   - the source code
    tar --mtime='1970-01-01' -cf ${key}.tar -C ${key} --sort=name --group=0 --owner=0 --numeric-owner --mode=777 .
    grep -v gitCommit ${key}.def | grep -v gitUrl > ${key}-nolabels.def 
    cat ${key}.tar ${key}-nolabels.def | sha256sum | awk '{print \$1}' | sed -e 's/\$/ ${key}/g' > ${key}.sha256sum
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
    tuple val(key), path("${key}-4fromRegistry.def"), emit: singularityRecipes4fromRegistry
    tuple val(key), path("${key}.sha256sum"), emit: sha256sum

  script:
    """
    cat << EOF > ${key}-4fromRegistry.def
    Bootstrap: docker
    From: TO_CHANGE_LATTER_ON

    %labels
        gitUrl ${params.gitUrl}
        gitCommit ${params.gitCommit}

    %environment
    EOF

    cat ${projectDir}/assets/def.env >> ${key}.def

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

workflow singularityRecipes {

  take:

  condaFilesCh
  condaFiles4Renv
  condaPackagesCh
  singularityRecipesCh
  fileDependenciesCh
  sourceCodeCh
  containerListCh

  main:

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

  // sha256sumCh contains
  // tuple val(key), file(sha256sum)
  // Example:
  // [alpine, /path/to/alpine.sha256sum]
  buildSingularityRecipeFromCondaFile4Renv.out.sha256sum
    .concat(buildSingularityRecipeFromSourceCode.out.sha256sum)
    .concat(buildSingularityRecipeFromCondaPackages.out.sha256sum)
    .concat(buildSingularityRecipeFromCondaFile.out.sha256sum)
    .concat(buildDefaultSingularityRecipe.out.sha256sum)
    .concat(sha256sumManualRecipes.out.sha256sum)
    .set{ sha256sumCh }

  // Select the list of tools if containerList has been provided.
  // containerList is a file which contains a subset of labels
  // for which to build the container (useful when we don't want
  // to build all the containers of the pipeline
  if (params.containerList != null) {
    sha256sumCh
      .join(containerListCh)
      .set{ sha256sumCh }
  }

  // Create a single sha256sum file with all the key and sha256sum value
  sha256sumFile(
    sha256sumCh
      .map{ it[1] }
      .collect()
  )

  // Create a channel with all the container recipes
  buildSingularityRecipeFromCondaFile4Renv.out.singularityRecipes
    .concat(buildSingularityRecipeFromSourceCode.out.singularityRecipes)
    .concat(buildSingularityRecipeFromCondaPackages.out.singularityRecipes)
    .concat(buildSingularityRecipeFromCondaFile.out.singularityRecipes)
    .concat(buildDefaultSingularityRecipe.out.singularityRecipes)
    .concat(singularityRecipesCh)
    .set {singularityAllRecipes}

  // Create a channel with all the container recipes
  // to build the sif from a docker registry
  buildSingularityRecipeFromCondaFile4Renv.out.singularityRecipes4fromRegistry
    .concat(buildSingularityRecipeFromSourceCode.out.singularityRecipes4fromRegistry)
    .concat(buildSingularityRecipeFromCondaPackages.out.singularityRecipes4fromRegistry)
    .concat(buildSingularityRecipeFromCondaFile.out.singularityRecipes4fromRegistry)
    .concat(buildDefaultSingularityRecipe.out.singularityRecipes4fromRegistry)
    .concat(sha256sumManualRecipes.out.singularityRecipes4fromRegistry)
    .set { singularityAllRecipes4fromRegistry }

  emit:

  singularityAllRecipes
  singularityAllRecipes4fromRegistry
}

