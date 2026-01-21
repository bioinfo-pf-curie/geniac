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

/*************
 * PROCESSES *
 *************/


/**
 *
 * apptainer profile
 *
 * Geniac documentation:
 *   - https://geniac.readthedocs.io/en/latest/run.html#run-profile-singularity
 *     (apptainer page not available on the geniac doc)
 *
 **/

// This process create on file for each tool to declare its 'withLabel' parameter.
process buildApptainerConfig {
  tag "${key}"

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
    if (params.condaNoDefaultsChannel) {
      condaChanEnv = String.join("\n      - ", ["bioconda", "conda-forge", "nodefaults"] + condaChansEnv)
    } else {
      condaChanEnv = String.join("\n      - ", ["bioconda", "conda-forge", "defaults"] + condaChansEnv)
    }
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

// This process creates one file for each tool to declare its 'withLabel' parameter.
process buildCondaConfig {
  tag "${key}"

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

  input:
    path(key)

  output:
    path("conda.config")

  script:
    """
    echo -e "conda {\n  cacheDir = \\\"\\\${params.condaCacheDir}\\\"\n  createTimeout = '1 h'\n  enabled = 'true'\n}\n" >> conda.config
    echo "process {"  >> conda.config

    beforescript_content="\$(cat ${projectDir}/assets/def.env | sed -e 's/    //g' -e 's/\"/\\\"/g' | sed -z 's/\\n/; /g')"
    echo "\n  beforeScript = \\\"\$beforescript_content export PATH=\\\$PATH:\\\${projectDir}/bin/fromSource\\\"\n" >> conda.config
    for keyFile in ${key}
    do
        cat \${keyFile} >> conda.config
    done
    echo "}"  >> conda.config
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

/**
 *
 * docker profile
 *
 * Geniac documentation:
 *   - https://geniac.readthedocs.io/en/latest/run.html#run-profile-docker
 *
 **/

// This process creates one file for each tool to declare its 'withLabel' parameter.
process buildDockerConfig {
  tag "${key}"

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


/**
 *
 * multiconda profile
 *
 * Geniac documentation:
 *   - https://geniac.readthedocs.io/en/latest/run.html#run-profile-multiconda
 *
 **/

// This process creates one file for each tool to declare its 'withLabel' parameter.
process buildMulticondaConfig {
  tag "${key}"

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


/**
 *
 * multipath profile
 *
 * Geniac documentation:
 *   - https://geniac.readthedocs.io/en/latest/run.html#run-profile-multipath
 *
 **/

// This process creates one file for each tool to declare its 'withLabel' parameter.
process buildMultiPathConfig {
  tag "${key}"

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

/**
 *
 * path profile
 *
 * Geniac documentation:
 *   - https://geniac.readthedocs.io/en/latest/run.html#run-profile-path
 *
 **/

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

/**
 *
 * podman profile
 *
 * Geniac documentation:
 *   - https://geniac.readthedocs.io/en/latest/run.html#run-profile-docker
 *     (podman page not available on the geniac doc)
 *
 **/

// This process creates the podman.config file from the docker.config file.
process buildPodmanConfig {
  tag "buildPodmanConfig"
  publishDir "${projectDir}/${params.publishDirConf}", overwrite: true, mode: 'copy'

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

/**
 *
 * singularity profile
 *
 * Geniac documentation:
 *   - https://geniac.readthedocs.io/en/latest/run.html#run-profile-singularity
 *
 **/

// This process create on file for each tool to declare its 'withLabel' parameter.
process buildSingularityConfig {
  tag "${key}"

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


workflow configFiles {

  take:

  condaChannelFromSpecsCh
  condaDepFromSpecsCh
  condaExistingEnvsCh
  condaFilesCh
  condaPackagesCh
  singularityAllRecipes

  main:


  // Create the apptainer config 
  buildApptainerConfig(singularityAllRecipes)
  mergeApptainerConfig(
    buildApptainerConfig.out.mergeApptainerConfig
      .toSortedList({ a, b -> a.getName().compareTo(b.getName()) }))

  // Get conda en information from yml files
  buildCondaDepFromRecipes(condaFilesCh)

  // Create the conda env (i.e. environment.yml file) used by the 'conda' profile
  buildCondaEnvFromCondaPackages(
    buildCondaDepFromRecipes.out.condaDepFromFiles
     .flatMap{ it.text.split() }
     .mix(condaDepFromSpecsCh)
     .unique()
     .toSortedList(),
    buildCondaDepFromRecipes.out.condaChanFromFiles
      .flatMap{ it.text.split() }
      .mix(condaChannelFromSpecsCh)
      .filter(~/!(bioconda|conda-forge|nodefaults|defaults)/) // only official channels are allowed
      .unique()
      .toSortedList()
      .ifEmpty('NO_CHANNEL'),
    buildCondaDepFromRecipes.out.condaPipDepFromFiles
      .flatMap{ it.text.split() }
      .unique()
      .toSortedList()
      .ifEmpty("")
  )

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

