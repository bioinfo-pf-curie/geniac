#!/usr/bin/env nextflow

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

// This process pushes the containers for all the tools on a registry
// It expects that:
// * you define the secret nextflow variable with the DOCKER_REGISTRY_PUSH_PASSWORD
//   (this environment variable must be defined in youir shell). You must run:
//   nextflow secrets set DOCKER_REGISTRY_PUSH_PASSWORD your_password
process pushDockerImages {
  maxForks 1
  tag "${key}"
  secret 'DOCKER_REGISTRY_PUSH_PASSWORD'

  input:
    tuple val(key), val(sha256sum), file(done)

  script:
    String dockerRegistryPushRepo = params.dockerRegistryPushRepo.replaceAll(/\/$/, '')
    """
    echo "push docker image for the tool ${key}"
    ${params.dockerCmd} login -u ${params.dockerRegistryPushUser} -p \$DOCKER_REGISTRY_PUSH_PASSWORD ${dockerRegistryPushRepo}
    ${params.dockerCmd} push ${params.dockerRegistryPushRepo}${key.toLowerCase()}:${sha256sum}
    """

  stub:
    String dockerRegistryPushRepo = params.dockerRegistryPushRepo.replaceAll(/\/$/, '')
    """
    echo "push docker image for the tool ${key}"
    echo ${params.dockerCmd} login -u ${params.dockerRegistryPushUser} -p \$DOCKER_REGISTRY_PUSH_PASSWORD ${dockerRegistryPushRepo}
    echo ${params.dockerCmd} push ${params.dockerRegistryPushRepo}${key.toLowerCase()}:${sha256sum}
    """
}
