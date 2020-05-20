# ##############################################################################
# Main core script
# ##############################################################################

# ##############################################################################
# Create the working directory
# ##############################################################################
# This is in is this directory that nextflow scripts will be launched to
# generate the config files, the recipes or the containers depending on the
# configure options that will be set with cmake
# ##############################################################################
set(workdir_depends_files
    ${pipeline_source_dir}/conf/base.config
    ${CMAKE_SOURCE_DIR}/install/singularity.nf
    ${CMAKE_SOURCE_DIR}/install/nextflow.config
    ${CMAKE_SOURCE_DIR}/install/docker.nf)

if(EXISTS ${pipeline_source_dir}/modules/)
    set(workdir_depends_files
        ${workdir_depends_files}
        ${pipeline_source_dir}/modules/*)
endif()

if(EXISTS ${pipeline_source_dir}/recipes/)
    set(workdir_depends_files
        ${workdir_depends_files}
        ${pipeline_source_dir}/recipes/*)
endif()

add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/workDir.done
    COMMAND ${CMAKE_COMMAND} -E echo "create workDir/"
    COMMAND ${CMAKE_COMMAND}
            -Dpipeline_source_dir=${pipeline_source_dir}
            -Dgeniac_source_dir=${CMAKE_SOURCE_DIR}
            -Dgeniac_binary_dir=${CMAKE_BINARY_DIR}
            -P ${CMAKE_SOURCE_DIR}/cmake/createWorkDir.cmake
    COMMAND ${CMAKE_COMMAND} -E touch "${CMAKE_BINARY_DIR}/workDir.done"
    DEPENDS ${workdir_depends_files})

# ##############################################################################
# Automatic generation of the config files, recipes and containers
# ##############################################################################

# generate conf/*.config files (singularity, docker, conda, multiconda, path,
# etc.) that will be used by the different nextflow profiles in the pipeline
add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/workDir/conf.done
    COMMAND ${CMAKE_COMMAND} -E echo "Build config files"
    COMMAND ${CMAKE_COMMAND} -E copy
            ${CMAKE_SOURCE_DIR}/install/singularity.nf
            ${CMAKE_BINARY_DIR}/workDir
    COMMAND
        ${NEXTFLOW_EXECUTABLE} run singularity.nf --buildConfigFiles true
        -with-report --gitCommit ${git_commit} --gitUrl ${git_url}
    COMMAND ${CMAKE_COMMAND} -E touch "${CMAKE_BINARY_DIR}/workDir/conf.done"
    COMMENT
        "Running command: ${NEXTFLOW_EXECUTABLE} run singularity.nf --buildConfigFiles true
        -with-report --gitCommit ${git_commit} --gitUrl ${git_url}"
    WORKING_DIRECTORY "${CMAKE_BINARY_DIR}/workDir"
    DEPENDS ${CMAKE_BINARY_DIR}/workDir.done)

# generate singularity recipes
add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/workDir/deffiles.done
    COMMAND ${CMAKE_COMMAND} -E echo "Build singularity recipe"
    COMMAND ${CMAKE_COMMAND} -E copy
            ${CMAKE_SOURCE_DIR}/install/singularity.nf
            ${CMAKE_BINARY_DIR}/workDir
    COMMAND
        ${NEXTFLOW_EXECUTABLE} run singularity.nf --buildSingularityRecipes true
        -with-report --gitCommit ${git_commit} --gitUrl ${git_url}
    COMMENT
        "Running command: ${NEXTFLOW_EXECUTABLE} run singularity.nf --buildSingularityRecipes true
        -with-report --gitCommit ${git_commit} --gitUrl ${git_url}"
    COMMAND ${CMAKE_COMMAND} -E touch
            "${CMAKE_BINARY_DIR}/workDir/deffiles.done"
    WORKING_DIRECTORY "${CMAKE_BINARY_DIR}/workDir"
    DEPENDS ${CMAKE_BINARY_DIR}/workDir.done)

# generate Dockerfiles
add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/workDir/Dockerfiles.done
    COMMAND ${CMAKE_COMMAND} -E echo "Build Dockerfiles"
    COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_SOURCE_DIR}/install/docker.nf
            ${CMAKE_BINARY_DIR}/workDir
    COMMAND
        ${NEXTFLOW_EXECUTABLE} run docker.nf --buildDockerfiles true
        -with-report --gitCommit ${git_commit} --gitUrl ${git_url}
    COMMENT "Running command: ${NEXTFLOW_EXECUTABLE} run docker.nf
        -with-report --gitCommit ${git_commit} --gitUrl ${git_url}"
    COMMAND ${CMAKE_COMMAND} -E touch
            "${CMAKE_BINARY_DIR}/workDir/Dockerfiles.done"
    WORKING_DIRECTORY "${CMAKE_BINARY_DIR}/workDir"
    DEPENDS ${CMAKE_BINARY_DIR}/workDir.done)

# allows the build of the singularity recipes with "make
# build_singularity_recipes"
add_custom_target(
    build_singularity_recipes
    COMMAND ${CMAKE_COMMAND} -E echo "Build singularity recipe"
    DEPENDS ${CMAKE_BINARY_DIR}/workDir/deffiles.done)

# allows the build of the docker recipes with "make build_docker_recipes"
add_custom_target(
    build_docker_recipes
    COMMAND ${CMAKE_COMMAND} -E echo "Build Dockerfiles"
    DEPENDS ${CMAKE_BINARY_DIR}/workDir/Dockerfiles.done)

# generate singularity recipes and images
add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/workDir/singularityImages.done
    COMMAND ${CMAKE_COMMAND} -E echo "Build singularity recipes and images"
    COMMAND ${CMAKE_COMMAND} -E copy
            ${CMAKE_SOURCE_DIR}/install/singularity.nf
            ${CMAKE_BINARY_DIR}/workDir
    COMMAND
        ${NEXTFLOW_EXECUTABLE} run singularity.nf --buildSingularityImages true
        -with-report --gitCommit ${git_commit} --gitUrl ${git_url}
    COMMENT
        "Running command: ${NEXTFLOW_EXECUTABLE} run singularity.nf --buildSingularityImages true
        -with-report --gitCommit ${git_commit} --gitUrl ${git_url}"
    COMMAND ${CMAKE_COMMAND} -E touch
            "${CMAKE_BINARY_DIR}/workDir/singularityImages.done"
    WORKING_DIRECTORY "${CMAKE_BINARY_DIR}/workDir"
    DEPENDS ${CMAKE_BINARY_DIR}/workDir.done)

# generate docker recipes and images
add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/workDir/dockerImages.done
    COMMAND ${CMAKE_COMMAND} -E echo "Build docker recipes and images"
    COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_SOURCE_DIR}/install/docker.nf
            ${CMAKE_BINARY_DIR}/workDir
    COMMAND
        ${NEXTFLOW_EXECUTABLE} run docker.nf --buildDockerImages true
        -with-report --gitCommit ${git_commit} --gitUrl ${git_url}
    COMMENT
        "Running command: ${NEXTFLOW_EXECUTABLE} run docker.nf --buildDockerImages true
        -with-report --gitCommit ${git_commit} --gitUrl ${git_url}"
    COMMAND ${CMAKE_COMMAND} -E touch
            "${CMAKE_BINARY_DIR}/workDir/dockerImages.done"
    WORKING_DIRECTORY "${CMAKE_BINARY_DIR}/workDir"
    DEPENDS ${CMAKE_BINARY_DIR}/workDir.done)

# allows the build of the singularity recipes and images with "make
# build_singularity_images"
add_custom_target(
    build_singularity_images
    COMMAND ${CMAKE_COMMAND} -E echo "Build singularity recipes and images"
    DEPENDS ${CMAKE_BINARY_DIR}/workDir/singularityImages.done)

# allows the build of the docker recipes and images with "make
# build_docker_images"
add_custom_target(
    build_docker_images
    COMMAND ${CMAKE_COMMAND} -E echo "Build docker recipes and images"
    DEPENDS ${CMAKE_BINARY_DIR}/workDir/dockerImages.done)

# check if singularity recipes option has been set
if(ap_install_singularity_recipes)
    message_color(INFO "Singularity recipes will be installed")

    add_custom_target(install_singularity_recipes ALL
                      DEPENDS ${CMAKE_BINARY_DIR}/workDir/deffiles.done)

    install(
        DIRECTORY "${CMAKE_BINARY_DIR}/workDir/${publish_dir_deffiles}/"
        DESTINATION
            "${CMAKE_INSTALL_PREFIX}/${pipeline_dir}/recipes/singularity")
endif()

# check docker recipes option has been set
if(ap_install_docker_recipes)
    message_color(INFO "Dockerfiles will be installed")

    add_custom_target(install_docker_recipes ALL
                      DEPENDS ${CMAKE_BINARY_DIR}/workDir/Dockerfiles.done)

    install(
        DIRECTORY "${CMAKE_BINARY_DIR}/workDir/${publish_dir_dockerfiles}/"
        DESTINATION "${CMAKE_INSTALL_PREFIX}/${pipeline_dir}/recipes/docker")
endif()

# check if singularity recipes and images has been set
if(ap_install_singularity_images)
    message_color(INFO "Singularity recipes and images will be installed")

    add_custom_target(
        install_singularity_images ALL
        DEPENDS ${CMAKE_BINARY_DIR}/workDir/singularityImages.done)

    install(
        DIRECTORY "${CMAKE_BINARY_DIR}/workDir/${publish_dir_deffiles}/"
        DESTINATION
            "${CMAKE_INSTALL_PREFIX}/${pipeline_dir}/recipes/singularity")

    install(
        DIRECTORY
            "${CMAKE_BINARY_DIR}/workDir/${publish_dir_singularity_images}/"
        DESTINATION "${CMAKE_INSTALL_PREFIX}/${singularity_image_dir}")

endif()

# check if docker recipes and images has been set
if(ap_install_docker_images)
    message_color(INFO "Docker recipes and images will be installed")

    add_custom_target(install_docker_images ALL
                      DEPENDS ${CMAKE_BINARY_DIR}/workDir/dockerImages.done)

    install(
        DIRECTORY "${CMAKE_BINARY_DIR}/workDir/${publish_dir_dockerfiles}/"
        DESTINATION "${CMAKE_INSTALL_PREFIX}/${pipeline_dir}/recipes/docker")

endif()

# install nextflow config generated automatically

add_custom_target(install_nextflow_config ALL
                  DEPENDS ${CMAKE_BINARY_DIR}/workDir/conf.done)
                
# Install generated config file(s)
install(
    DIRECTORY "${CMAKE_BINARY_DIR}/workDir/${publish_dir_conf}/"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/${pipeline_dir}/conf"
    FILES_MATCHING
    PATTERN "*.config")

# Install generated conda file(s)
install(
    DIRECTORY "${CMAKE_BINARY_DIR}/workDir/${publish_dir_conda}/"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/${pipeline_dir}"
    FILES_MATCHING
    PATTERN "*.yml")
# ##############################################################################
# Setup path directories
# ##############################################################################

add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/pathDirectories.done
    COMMAND
        ${CMAKE_COMMAND}
        -Dpath_link_file=${CMAKE_BINARY_DIR}/workDir/${publish_dir_conf}/pathLink.txt
        -Dpath_link_dir=${CMAKE_BINARY_DIR}/pathDirectories -P
        ${CMAKE_SOURCE_DIR}/cmake/createPathDirectories.cmake
    COMMAND ${CMAKE_COMMAND} -E touch "${CMAKE_BINARY_DIR}/pathDirectories.done"
    DEPENDS ${CMAKE_BINARY_DIR}/workDir/conf.done)

add_custom_target(install_path_directories ALL
                  DEPENDS ${CMAKE_BINARY_DIR}/pathDirectories.done)

install(DIRECTORY ${CMAKE_BINARY_DIR}/pathDirectories/
        DESTINATION ${CMAKE_INSTALL_PREFIX}/path)
