/*

This file is part of geniac.

Copyright Institut Curie 2020-2025.

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

// This process creates the containers for all the tools
process buildImages {
  maxForks 1
  tag "${key}"
  publishDir "${projectDir}/${params.publishDirSingularityImages}", overwrite: true, mode: 'copy'

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
    echo singularity build ${params.singularityBuildOptions} ${key.toLowerCase()}.sif ${singularityRecipe} > ${key.toLowerCase()}.sif
    """
}

// This process creates the containers for all the tools
process buildImagesFromRegistry {
  maxForks 1
  tag "${key}"
  publishDir "${projectDir}/${params.publishDirSingularityImages}", overwrite: true, mode: 'copy'

  input:
    tuple val(key), file(singularityRecipe), val(sha256sum)

  output:
    path("${key.toLowerCase()}.sif")

  script:
    """
    sed -e "s|From:.*|From: ${params.dockerPushRegistry}${key}:${sha256sum}|g" ${singularityRecipe} > ${key}-from-docker-registry.def
    singularity build ${params.singularityBuildOptions} ${key.toLowerCase()}.sif ${key}-from-docker-registry.def
    singularity build ${params.singularityBuildOptions} ${key.toLowerCase()}.sif ${key}-from-docker-registry.def >  ${key.toLowerCase()}.sif
    """

  stub:
    """
    sed -e "s|From:.*|From: ${params.dockerPushRegistry}${key}:${sha256sum}|g" ${singularityRecipe} > ${key}-from-docker-registry.def
    echo singularity build ${params.singularityBuildOptions} ${key.toLowerCase()}.sif ${key}-from-docker-registry.def >  ${key.toLowerCase()}.sif
    """
}
