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

if(EXISTS ${pipeline_source_dir}/modules/)
    file(COPY ${pipeline_source_dir}/modules/ DESTINATION ${geniac_binary_dir}/workDir/modules)
else()
    file(MAKE_DIRECTORY ${geniac_binary_dir}/workDir/modules)
endif()

if(EXISTS ${pipeline_source_dir}/recipes/)
    file(COPY ${pipeline_source_dir}/recipes/ DESTINATION ${geniac_binary_dir}/workDir/recipes)
endif()

