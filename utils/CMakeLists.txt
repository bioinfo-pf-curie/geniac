include("cmake/utilsColorMessage.cmake")
include("cmake/utilsSetVariables.cmake")
include("cmake/utilsFindPackages.cmake")
include("cmake/utilsCheckOptions.cmake")
include("cmake/utilsGitInfo.cmake")

# ##############################################################################
# Fill template for config files
# ##############################################################################

file(GLOB ap_conf_template_file_list "${CMAKE_SOURCE_DIR}/conf/templates/*.in")

foreach(file ${ap_conf_template_file_list})
    get_filename_component(file ${file} NAME)
    string(REGEX REPLACE ".in$" "" file_output ${file})
    message_color(INFO "configure: ${file} into ${file_output}")

    configure_file(${CMAKE_SOURCE_DIR}/conf/templates/${file}
                   ${CMAKE_BINARY_DIR}/nextflowConf/${file_output} @ONLY)
    install(FILES ${CMAKE_BINARY_DIR}/nextflowConf/${file_output}
            DESTINATION ${CMAKE_INSTALL_PREFIX}/${pipeline_dir}/conf)

endforeach(file ${ap_conf_template_file_list})

# ##############################################################################
# Container recipes and images
# ##############################################################################

# working directory to build: - the container recipes and images - the nextflow
# config files
add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/workDir.done
    COMMAND ${CMAKE_COMMAND} -E echo "create workDir/"
    COMMAND ${CMAKE_COMMAND} -E copy_directory ${CMAKE_SOURCE_DIR}/recipes
            ${CMAKE_BINARY_DIR}/workDir/recipes
    COMMAND ${CMAKE_COMMAND} -E copy_directory ${CMAKE_BINARY_DIR}/nextflowConf
            ${CMAKE_BINARY_DIR}/workDir/conf/
    COMMAND ${CMAKE_COMMAND} -E copy
            ${CMAKE_SOURCE_DIR}/utils/install/nextflow.config
            ${CMAKE_BINARY_DIR}/workDir/
    COMMAND ${CMAKE_COMMAND} -E copy_directory ${CMAKE_SOURCE_DIR}/conf
            ${CMAKE_BINARY_DIR}/workDir/conf
    COMMAND ${CMAKE_COMMAND} -E copy
            ${CMAKE_SOURCE_DIR}/utils/install/singularity.nf
            ${CMAKE_BINARY_DIR}/workDir
    COMMAND ${CMAKE_COMMAND} -E copy_directory ${CMAKE_SOURCE_DIR}/modules
            ${CMAKE_BINARY_DIR}/workDir/modules
    COMMAND ${CMAKE_COMMAND} -E touch "${CMAKE_BINARY_DIR}/workDir.done"
    DEPENDS ${CMAKE_SOURCE_DIR}/recipes/*
    DEPENDS ${CMAKE_SOURCE_DIR}/conf/base.config
    DEPENDS ${CMAKE_SOURCE_DIR}/modules/*
    DEPENDS ${CMAKE_SOURCE_DIR}/utils/install/singularity.nf
    DEPENDS ${CMAKE_SOURCE_DIR}/utils/install/nextflow.config
    DEPENDS ${CMAKE_SOURCE_DIR}/utils/install/docker.nf)

# generate conf/*.config files (singularity, docker, conda, multiconda, path,
# etc.)
add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/workDir/conf.done
    COMMAND ${CMAKE_COMMAND} -E echo "Build config files"
    COMMAND ${CMAKE_COMMAND} -E copy
            ${CMAKE_SOURCE_DIR}/utils/install/singularity.nf
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
            ${CMAKE_SOURCE_DIR}/utils/install/singularity.nf
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
    COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_SOURCE_DIR}/utils/install/docker.nf
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

# allows the build of the singularity recipes with "make build_singularity_recipes"
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
            ${CMAKE_SOURCE_DIR}/utils/install/singularity.nf
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

# generate singularity recipes and images
add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/workDir/dockerImages.done
    COMMAND ${CMAKE_COMMAND} -E echo "Build docker recipes and images"
    COMMAND ${CMAKE_COMMAND} -E copy
            ${CMAKE_SOURCE_DIR}/utils/install/docker.nf
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

# allows the build of the singularity recipes and images with "make
# build_singularity_images"
add_custom_target(
    build_docker_images
    COMMAND ${CMAKE_COMMAND} -E echo "Build docker recipes and images"
    DEPENDS ${CMAKE_BINARY_DIR}/workDir/dockerImages.done)

# singularity
if(ap_install_singularity_recipes)
    message_color(INFO "Singularity recipes will be installed")

    add_custom_target(install_singularity_recipes ALL
                      DEPENDS ${CMAKE_BINARY_DIR}/workDir/deffiles.done)

    install(
        DIRECTORY "${CMAKE_BINARY_DIR}/workDir/${publish_dir_deffiles}/"
        DESTINATION
            "${CMAKE_INSTALL_PREFIX}/${pipeline_dir}/recipes/singularity")
endif()

# docker
if(ap_install_docker_recipes)
    message_color(INFO "Dockerfiles will be installed")

    add_custom_target(install_docker_recipes ALL
                      DEPENDS ${CMAKE_BINARY_DIR}/workDir/Dockerfiles.done)

    install(
        DIRECTORY "${CMAKE_BINARY_DIR}/workDir/${publish_dir_dockerfiles}/"
        DESTINATION "${CMAKE_INSTALL_PREFIX}/${pipeline_dir}/recipes/docker")
endif()

# singularity
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

# docker
if(ap_install_docker_images)
    message_color(INFO "Docker recipes and images will be installed")

    add_custom_target(
        install_docker_images ALL
        DEPENDS ${CMAKE_BINARY_DIR}/workDir/dockerImages.done)

    install(
        DIRECTORY "${CMAKE_BINARY_DIR}/workDir/${publish_dir_dockerfiles}/"
        DESTINATION
            "${CMAKE_INSTALL_PREFIX}/${pipeline_dir}/recipes/docker")

endif()

# nextflow config

add_custom_target(install_nextflow_config ALL
                  DEPENDS ${CMAKE_BINARY_DIR}/workDir/conf.done)

install(
    DIRECTORY "${CMAKE_BINARY_DIR}/workDir/${publish_dir_conf}/"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/${pipeline_dir}/conf"
    FILES_MATCHING
    PATTERN "*.config")

# ##############################################################################
# Setup path directories
# ##############################################################################

add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/pathDirectories.done
    COMMAND
        ${CMAKE_COMMAND}
        -Dpath_link_file=${CMAKE_BINARY_DIR}/workDir/${publish_dir_conf}/pathLink.txt
        -Dpath_link_dir=${CMAKE_BINARY_DIR}/pathDirectories -P
        ${CMAKE_SOURCE_DIR}/utils/cmake/createPathDirectories.cmake
    COMMAND ${CMAKE_COMMAND} -E touch "${CMAKE_BINARY_DIR}/pathDirectories.done"
    DEPENDS ${CMAKE_BINARY_DIR}/workDir/conf.done)

add_custom_target(install_path_directories ALL
                  DEPENDS ${CMAKE_BINARY_DIR}/pathDirectories.done)

install(DIRECTORY ${CMAKE_BINARY_DIR}/pathDirectories/
        DESTINATION ${CMAKE_INSTALL_PREFIX}/path)

# ##############################################################################
# Custom targets for tests
# ##############################################################################

set(profile_list "standard" "conda" "multiconda" "singularity" "docker" "path")

add_custom_target(
    myinstall
    COMMAND ${CMAKE_COMMAND} -E echo "Install"
    COMMAND ${CMAKE_COMMAND} --build . --target install
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR})

foreach(profile_i ${profile_list})

    add_custom_target(
        test_${profile_i}
        COMMAND ${CMAKE_COMMAND} -E echo "Start test profile ${profile_i}"
        COMMAND
            ${NEXTFLOW_EXECUTABLE} run main.nf -c conf/test.config -profile
            ${profile_i}
        WORKING_DIRECTORY ${CMAKE_INSTALL_PREFIX}/pipeline
        DEPENDS myinstall)

    add_custom_target(
        test_${profile_i}_cluster
        COMMAND ${CMAKE_COMMAND} -E echo "Start test profile ${profile_i}"
        COMMAND
            ${NEXTFLOW_EXECUTABLE} run main.nf -c conf/test.config -profile
            ${profile_i},cluster
        WORKING_DIRECTORY ${CMAKE_INSTALL_PREFIX}/pipeline
        DEPENDS myinstall)

endforeach()
