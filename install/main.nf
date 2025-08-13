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

nextflow.enable.dsl=2

/*****************
 * CHANNELS INIT *
 *****************/

// Channel with conda env info form geniac.config
Channel
  .from(params.geniac.tools)
  .flatMap {
    List<String> result = []
    for (Map.Entry<String, String> entry : it.entrySet()) {
      if (entry.value instanceof String || entry.value instanceof GString) {
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

condaPackagesCh
  .multiMap { pTool -> 
    condaChannelFromSpecs: pTool[1][0]
    condaDepFromSpecs: pTool[1][1]
  }
  .set { condaPackages }

// The 2 following channels contain information
// about conda env defined in the geniac.config file
condaChannelFromSpecsCh = condaPackages.condaChannelFromSpecs
condaDepFromSpecsCh = condaPackages.condaDepFromSpecs

// DOCKER RECIPES
Channel
  .fromPath("${projectDir}/recipes/docker/*.Dockerfile")
  .map{ [it.simpleName, it] }
  .set{ dockerRecipesCh }

// SINGULARITY RECIPES
Channel
  .fromPath("${projectDir}/recipes/singularity/*.def")
  .map{ [it.simpleName, it] }
  .set{ singularityRecipesCh }

// CONDA RECIPES
Channel
  .fromPath("${projectDir}/recipes/conda/*.yml")
  .map{ [it.simpleName, it] }
  .set{ condaRecipesCh }

// DEPENDENCIES
Channel
  .fromPath("${projectDir}/recipes/dependencies/*", type: 'dir')
  .map{ [it.name, it] }
  .ifEmpty(['NO_DEPENDENCIES', file('NO_DEPENDENCIES')])
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

/*
==================================
           INCLUDE
==================================
*/

// Processes
include { buildImages as buildSingularityImages } from './nf-modules/local/process/singularityImages'
include { buildImages as buildDockerImages } from './nf-modules/local/process/dockerImages'
include { pushDockerImages} from './nf-modules/local/process/pushDockerImages'

// Subworkflows
include { configFiles } from './nf-modules/local/subworkflow/configFilesWkfl'
include { dockerRecipes } from './nf-modules/local/subworkflow/dockerRecipesWkfl'
include { singularityRecipes } from './nf-modules/local/subworkflow/singularityRecipesWkfl'

workflow {

  main:

  ///////////////////////
  // Container recipes //
  ///////////////////////

  if (params.buildSingularityRecipes) {
    singularityRecipes(
      condaFilesCh,
      condaFiles4Renv,
      condaPackagesCh,
      singularityRecipesCh,
      fileDependenciesCh,
      sourceCodeCh
    )
  }
  
  if (params.buildDockerRecipes) {
    dockerRecipes(
      condaFilesCh,
      condaFiles4Renv,
      condaPackagesCh,
      dockerRecipesCh,
      fileDependenciesCh,
      sourceCodeCh
    )
  }

  //////////////////
  // Config files //
  //////////////////

  if (params.buildConfigFiles && params.buildSingularityRecipes) {
    configFiles(
      condaChannelFromSpecsCh,
      condaDepFromSpecsCh,
      condaExistingEnvsCh,
      condaFilesCh,
      condaPackagesCh,
      singularityRecipes.out.singularityAllRecipes
    )
  } else {
    if(params.buildConfigFiles && !params.buildSingularityRecipes) {
      exit 1, "In order to build the config files, you must also enable the option --buildSingularityRecipes. This is necessary to obtain the list of all the containers."
    }
  }

  ////////////////////////////
  // Build container images //
  ////////////////////////////

  if (params.buildSingularityImages && params.buildSingularityRecipes) {
    buildSingularityImages(
      singularityRecipes.out.singularityAllRecipes
        .join(fileDependenciesCh, remainder: true)
        .join(condaRecipesCh, remainder: true)
        .join(sourceCodeCh, remainder: true)
        .filter{ it[1] }
    )
  } else {
    if(params.buildSingularityImages && !params.buildSingularityRecipes) {
      exit 1, "In order to build the singularity images, you must also enable the option --buildSingularityRecipes. This is necessary to obtain the list of all the containers and their recipes."
    }
  }

  
  if (params.buildDockerImages && params.buildDockerRecipes) {
    buildDockerImages(
      dockerRecipes.out.dockerAllRecipes
        .join(fileDependenciesCh, remainder: true)
        .join(condaRecipesCh, remainder: true)
        .join(sourceCodeCh, remainder: true)
        .filter{ it[1] }
	  		.join(dockerRecipes.out.sha256sumValCh)
    )
  } else {
    if(params.buildDockerImages && !params.buildDockerRecipes) {
      exit 1, "In order to build the docker images, you must also enable the option --buildDockerRecipes. This is necessary to obtain the list of all the containers and their recipes."
    }
  }


  // Push the docker containers on the registry
  if (params.pushDockerImages && params.buildDockerImages) {
    pushDockerImages(
      dockerRecipes.out.sha256sumValCh
        .join(buildDockerImages.out.done)
    )
  } else {
    if(params.pushDockerImages && !params.buildDockerImages) {
      exit 1, "In order to push the docker images, you must also enable the option --buildDockerImages. This is necessary to first build the containers images."
    }
  }


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

