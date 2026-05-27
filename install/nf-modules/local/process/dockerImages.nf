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


  input:
    tuple val(key), file(dockerRecipe), file(fileDepDir), file(condaRecipe), file(sourceCodeDir), val(sha256sum)

  output:
    tuple val(key), file("${key}.done"), emit: done

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
    if (params.dockerCmd == "podman") {
      buildOptions = "--format docker"
    } else {
      buildOptions = ""
    }
    """
    # docker (with new version using buildx complains if the synlink is outside the contextDir
    # the use of realpath solves this issues
    ${params.dockerCmd} build ${buildOptions} -f \$(realpath ${dockerRecipe}) -t ${key.toLowerCase()} -t ${params.dockerRegistryPushRepo}${key.toLowerCase()}:${sha256sum} ${contextDir}
    touch ${key}.done
    """

  stub:
    String contextDir = '.'
    if (params.dockerCmd == "podman") {
      buildOptions = "--format docker"
    } else {
      buildOptions = ""
    }
    """
    echo "build docker image for the tool ${key}"
    echo ${params.dockerCmd} build ${buildOptions} -f \$(realpath ${dockerRecipe}) -t ${key.toLowerCase()} -t ${params.dockerRegistryPushRepo}${key.toLowerCase()}:${sha256sum} ${contextDir}
    touch ${key}.done
    """
  
}
