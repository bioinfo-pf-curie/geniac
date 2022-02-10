#######################################################################################
# This file is part of geniac.
# 
# Copyright Institut Curie 2020.
# 
# This software is a computer program whose purpose is to perform
# Automatic Configuration GENerator and Installer for nextflow pipeline.
# 
# You can use, modify and/ or redistribute the software under the terms
# of license (see the LICENSE file for more details).
# 
# The software is distributed in the hope that it will be useful,
# but "AS IS" WITHOUT ANY WARRANTY OF ANY KIND.
# Users are therefore encouraged to test the software's suitability as regards
# their requirements in conditions enabling the security of their systems and/or data.
# 
# The fact that you are presently reading this means that you have had knowledge
# of the license and that you accept its terms.
#######################################################################################


# Create workDir

# Add geniac.config file in nextflow.config if it exists otherwise use
if(EXISTS ${pipeline_source_dir}/conf/geniac.config)
	set(geniac_config_string "includeConfig 'conf/geniac.config'")
else()
	set(geniac_config_string "")
endif()

configure_file(
	${geniac_source_dir}/install/nextflow.config.in
	${geniac_binary_dir}/workDir/nextflow.config
	@ONLY
)

file(COPY ${geniac_source_dir}/install/singularity.nf DESTINATION ${geniac_binary_dir}/workDir)
file(COPY ${geniac_source_dir}/install/docker.nf DESTINATION ${geniac_binary_dir}/workDir)
file(COPY ${pipeline_source_dir}/conf/ DESTINATION ${geniac_binary_dir}/workDir/conf)

if(EXISTS ${pipeline_source_dir}/modules/fromSource/)
    file(COPY ${pipeline_source_dir}/modules/fromSource/ DESTINATION ${geniac_binary_dir}/workDir/modules/fromSource)
else()
    file(MAKE_DIRECTORY ${geniac_binary_dir}/workDir/modules/fromSource)
endif()

if(EXISTS ${pipeline_source_dir}/recipes/)
    file(COPY ${pipeline_source_dir}/recipes/ DESTINATION ${geniac_binary_dir}/workDir/recipes)
endif()

