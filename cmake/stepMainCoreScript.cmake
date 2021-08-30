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
    ${pipeline_source_dir}/conf/geniac.config
    ${CMAKE_SOURCE_DIR}/install/singularity.nf
    ${CMAKE_SOURCE_DIR}/install/nextflow.config.in
    ${CMAKE_SOURCE_DIR}/install/docker.nf)

if(EXISTS ${pipeline_source_dir}/modules/fromSource/)
    set(workdir_depends_files
        ${workdir_depends_files}
        ${pipeline_source_dir}/modules/fromSource/*)
endif()

if(EXISTS ${pipeline_source_dir}/recipes/)
    set(workdir_depends_files
        ${workdir_depends_files}
        ${pipeline_source_dir}/recipes/*)
endif()

add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/workDir.done
    COMMAND ${CMAKE_COMMAND}
            -Dpipeline_source_dir=${pipeline_source_dir}
            -Dgeniac_source_dir=${CMAKE_SOURCE_DIR}
            -Dgeniac_binary_dir=${CMAKE_BINARY_DIR}
            -Ddocker_registry=${ap_docker_registry}
            -Dlinux_distro=${ap_linux_distro}
            -Dconda_release=${ap_conda_release}
            -P ${CMAKE_SOURCE_DIR}/cmake/createWorkDir.cmake
    COMMAND ${CMAKE_COMMAND} -E echo "workDir/ has been created"
    COMMAND ${CMAKE_COMMAND} -E touch "${CMAKE_BINARY_DIR}/workDir.done"
    COMMENT "Creation of the workDir for cmake"
    DEPENDS ${workdir_depends_files})

# ##############################################################################
# Automatic generation of the config files, recipes and containers
# ##############################################################################

# generate conf/*.config files (singularity, docker, conda, multiconda, path,
# multipath.) that will be used by the different nextflow profiles in the pipeline
add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/workDir/conf.done
    COMMAND ${CMAKE_COMMAND} -E echo "Build config files"
    COMMAND
        ${NEXTFLOW_EXECUTABLE} run -resume singularity.nf --buildConfigFiles true
        -with-report --gitCommit ${git_commit} --gitUrl ${git_url} --clusterExecutor ${ap_nf_executor}
    COMMAND ${CMAKE_COMMAND} -E touch "${CMAKE_BINARY_DIR}/workDir/conf.done"
    COMMENT
        "Running command: ${NEXTFLOW_EXECUTABLE} run -resume singularity.nf --buildConfigFiles true
        -with-report --gitCommit ${git_commit} --gitUrl ${git_url}"
    WORKING_DIRECTORY "${CMAKE_BINARY_DIR}/workDir"
    DEPENDS ${CMAKE_BINARY_DIR}/workDir.done)

# compare the conf/*.config files that have been generated with
# the same file in the git repo if they exist
add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/comparison.done
    COMMAND
        ${CMAKE_COMMAND} -Dconfig_files_dir=${CMAKE_BINARY_DIR}/workDir/results/conf
        -Dconfig_files_in_git_dir=${CMAKE_SOURCE_DIR}/../conf
        -Dap_nf_executor=${ap_nf_executor}
        -DGIT_EXECUTABLE=${GIT_EXECUTABLE}
        -P ${CMAKE_SOURCE_DIR}/cmake/checkConfigFiles.cmake
    COMMAND ${CMAKE_COMMAND} -E touch "${CMAKE_BINARY_DIR}/comparison.done"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
    COMMENT "Check if config files are present in the git repository and compare them with generated config files"
    DEPENDS ${CMAKE_BINARY_DIR}/workDir/conf.done)

# generate singularity recipes
add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/workDir/deffiles.done
    COMMAND ${CMAKE_COMMAND} -E echo "Build singularity recipe"
    COMMAND
        ${NEXTFLOW_EXECUTABLE} run -resume singularity.nf --buildSingularityRecipes true
        -with-report --gitCommit ${git_commit} --gitUrl ${git_url} --clusterExecutor ${ap_nf_executor}
    COMMENT
        "Running command: ${NEXTFLOW_EXECUTABLE} run -resume singularity.nf --buildSingularityRecipes true
        -with-report --gitCommit ${git_commit} --gitUrl ${git_url}"
    COMMAND ${CMAKE_COMMAND} -E touch
            "${CMAKE_BINARY_DIR}/workDir/deffiles.done"
    WORKING_DIRECTORY "${CMAKE_BINARY_DIR}/workDir"
    DEPENDS ${CMAKE_BINARY_DIR}/workDir.done)

# generate Dockerfiles
add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/workDir/Dockerfiles.done
    COMMAND ${CMAKE_COMMAND} -E echo "Build Dockerfiles"
    COMMAND
        ${NEXTFLOW_EXECUTABLE} run -resume docker.nf --buildDockerfiles true
        -with-report --gitCommit ${git_commit} --gitUrl ${git_url}
    COMMENT "Running command: ${NEXTFLOW_EXECUTABLE} run -resume docker.nf
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
    COMMAND ${CMAKE_COMMAND} ${CMAKE_SOURCE_DIR} -Dap_install_singularity_recipes=ON
    WORKING_DIRECTORY "${CMAKE_BINARY_DIR}"
    DEPENDS ${CMAKE_BINARY_DIR}/workDir/deffiles.done)

# allows the build of the docker recipes with "make build_docker_recipes"
add_custom_target(
    build_docker_recipes
    COMMAND ${CMAKE_COMMAND} -E echo "Build Dockerfiles"
    COMMAND ${CMAKE_COMMAND} ${CMAKE_SOURCE_DIR} -Dap_install_docker_recipes=ON
    WORKING_DIRECTORY "${CMAKE_BINARY_DIR}"
    DEPENDS ${CMAKE_BINARY_DIR}/workDir/Dockerfiles.done)

# generate singularity recipes and images
add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/workDir/singularityImages.done
    COMMAND ${CMAKE_COMMAND} -E echo "Build singularity recipes and images"
    COMMAND
        ${NEXTFLOW_EXECUTABLE} run -resume singularity.nf --buildSingularityImages true
        -with-report --gitCommit ${git_commit} --gitUrl ${git_url} --clusterExecutor ${ap_nf_executor}
    COMMENT
        "Running command: ${NEXTFLOW_EXECUTABLE} run -resume singularity.nf --buildSingularityImages true
        -with-report --gitCommit ${git_commit} --gitUrl ${git_url}"
    COMMAND ${CMAKE_COMMAND} -E touch
            "${CMAKE_BINARY_DIR}/workDir/singularityImages.done"
    WORKING_DIRECTORY "${CMAKE_BINARY_DIR}/workDir"
    DEPENDS ${CMAKE_BINARY_DIR}/workDir.done)

# generate docker recipes and images
add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/workDir/dockerImages.done
    COMMAND ${CMAKE_COMMAND} -E echo "Build docker recipes and images"
    COMMAND
        ${NEXTFLOW_EXECUTABLE} run -resume docker.nf --buildDockerImages true
        -with-report --gitCommit ${git_commit} --gitUrl ${git_url}
    COMMENT
        "Running command: ${NEXTFLOW_EXECUTABLE} run -resume docker.nf --buildDockerImages true
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

# check the config files
if(ap_check_config_file_from_source)

  add_custom_target(check_nextflow_config_files ALL
                    DEPENDS ${CMAKE_BINARY_DIR}/comparison.done)

endif()


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
    OUTPUT ${CMAKE_BINARY_DIR}/multiPathDirectories.done
    COMMAND
        ${CMAKE_COMMAND}
        -Dpath_link_file=${CMAKE_BINARY_DIR}/workDir/${publish_dir_conf}/multiPathLink.txt
        -Dpath_link_dir=${CMAKE_BINARY_DIR}/multiPathDirectories -P
        ${CMAKE_SOURCE_DIR}/cmake/createPathDirectories.cmake
    COMMAND ${CMAKE_COMMAND} -E touch "${CMAKE_BINARY_DIR}/multiPathDirectories.done"
    DEPENDS ${CMAKE_BINARY_DIR}/workDir/conf.done)

install(DIRECTORY ${CMAKE_BINARY_DIR}/multiPathDirectories/
        DESTINATION ${CMAKE_INSTALL_PREFIX}/multipath)

add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/pathDirectory.done
    COMMAND
        ${CMAKE_COMMAND}
        -Dpath_link_file=${CMAKE_BINARY_DIR}/workDir/${publish_dir_conf}/PathLink.txt
        -Dpath_link_dir=${CMAKE_BINARY_DIR}/PathDirectory -P
        ${CMAKE_SOURCE_DIR}/cmake/createPathDirectories.cmake
    COMMAND ${CMAKE_COMMAND} -E touch "${CMAKE_BINARY_DIR}/pathDirectory.done"
    DEPENDS ${CMAKE_BINARY_DIR}/workDir/conf.done)

install(DIRECTORY ${CMAKE_BINARY_DIR}/PathDirectory/
        DESTINATION ${CMAKE_INSTALL_PREFIX}/path)

add_custom_target(install_path_directories ALL
                  DEPENDS ${CMAKE_BINARY_DIR}/multiPathDirectories.done ${CMAKE_BINARY_DIR}/pathDirectory.done)

# ##############################################################################
# Keep environment.yml file from the source code
# The environment.yml generated by geniac will be discarded
# As it can be impossible to automatically generate the conda recipe we may have no choice but
# to write the environment.yml manually.
# Leave this step at the end of this script.
# ##############################################################################

if(ap_keep_envyml_from_source)
  if(EXISTS ${pipeline_source_dir}/environment.yml)
    install(FILES ${pipeline_source_dir}/environment.yml DESTINATION ${pipeline_dir})
    message_color(INFO "The environment.yml from the source code will be installed (the file automatically generated by geniac will be discarded).")
  endif()
endif()
