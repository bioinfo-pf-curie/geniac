
# Create workDir

file(COPY ${geniac_source_dir}/install/singularity.nf DESTINATION ${geniac_binary_dir}/workDir)
file(COPY ${geniac_source_dir}/install/docker.nf DESTINATION ${geniac_binary_dir}/workDir)
file(COPY ${geniac_source_dir}/install/nextflow.config DESTINATION ${geniac_binary_dir}/workDir)
file(COPY ${pipeline_source_dir}/conf/ DESTINATION ${geniac_binary_dir}/workDir/conf)

if(EXISTS ${pipeline_source_dir}/modules/)
    file(COPY ${pipeline_source_dir}/modules/ DESTINATION ${geniac_binary_dir}/workDir/modules)
endif()

if(EXISTS ${pipeline_source_dir}/recipes/)
    file(COPY ${pipeline_source_dir}/recipes/ DESTINATION ${geniac_binary_dir}/workDir/recipes)
endif()

