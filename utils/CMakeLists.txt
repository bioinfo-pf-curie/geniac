set(CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/utils/cmake;${CMAKE_MODULE_PATH}")

include("cmake/utils.cmake")

set(ap_install_singularity_recipes
    "OFF"
    CACHE BOOL "Generate and install singularity def files")

set(ap_install_singularity_images
    "OFF"
    CACHE BOOL "Generate and install Singularity def files and images")

set(ap_install_docker_recipes
    "OFF"
    CACHE BOOL "Generate and install Dockerfiles")

set(ap_install_docker_images
    "OFF"
    CACHE BOOL "Generate and install Dockerfiles and images")

find_package(Git 2.0)
find_package(Nextflow 19.10)
find_package(Singularity 3.2)
find_package(Docker 18.0)

if(GIT_FOUND)
    message_color(OK "Git found")
else()
    message_color(WARNING "Git not found")
endif()

if(NEXTFLOW_FOUND)
    message_color(OK "Nextflow found")
else()
    message_color(FATAL_ERROR
                  "Nextflow not found. It is required during the build step.")
endif()

if(SINGULARITY_FOUND)
    message_color(OK "Singularity found")
else()
    message_color(WARNING "Singularity not found")
endif()

if(DOCKER_FOUND)
    message_color(OK "Docker found")
else()
    message_color(WARNING "Docker not found")
endif()

# ##############################################################################
# Check that options match requirement
# ##############################################################################
if(ap_install_singularity_images)

    if(NOT NEXTFLOW_FOUND OR NOT SINGULARITY_FOUND)
        message_color(
            FATAL_ERROR
            "Both singularity and nextflow are required with options ap_install_singularity_images
			or ap_install_singularity_recipes set to ON ")
    else()

        if(ap_install_singularity_images)
            message_color(
                WARNING
                "ap_install_singularity_images is ON: root privilege will be required during make step"
            )
        endif()

    endif()

endif()

if(ap_install_docker_images)

    if(NOT NEXTFLOW_FOUND OR NOT DOCKER_FOUND)
        message_color(
            FATAL_ERROR
            "Both docker and nextflow are required with options ap_install_singularity_images
					or ap_install_singularity_recipes set to ON ")

    else()

        if(ap_install_docker_images)
            message_color(
                WARNING
                "ap_install_docker_images is ON: root privilege will be required during make step"
            )
        endif()
    endif()

endif()

# ##############################################################################
# GIT INFORMATION
# ##############################################################################

if(NOT IS_DIRECTORY ${CMAKE_SOURCE_DIR}/.git)
    message_color(FATAL_ERROR "Source directory is not a git repository")
endif()

if(GIT_FOUND)

    # extract the commid id
    execute_process(
        COMMAND ${GIT_EXECUTABLE} rev-parse HEAD
        WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
        OUTPUT_VARIABLE git_commit
        ERROR_QUIET OUTPUT_STRIP_TRAILING_WHITESPACE)

    if("${git_commit}" STREQUAL "")
        message_color(FATAL_ERROR "git commit sha1 is empty")
    else()
        message(STATUS "GIT hash: ${git_commit}")
    endif()

    # extract the remothe URL of the git repository and extract its name
    execute_process(
        COMMAND ${GIT_EXECUTABLE} remote get-url origin
        WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
        OUTPUT_VARIABLE git_url
        ERROR_QUIET OUTPUT_STRIP_TRAILING_WHITESPACE)

    string(REGEX REPLACE ".*/" "" git_repo_name ${git_url})
    string(REGEX REPLACE ".git$" "" git_repo_name ${git_repo_name})

    message(STATUS "GIT repository name: ${git_repo_name}")

    # check whether the commit sha1 exists on the release branch
    execute_process(
        COMMAND ${GIT_EXECUTABLE} branch release --contains ${git_commit}
        WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
        OUTPUT_VARIABLE _commit_in_release
        ERROR_QUIET OUTPUT_STRIP_TRAILING_WHITESPACE)

    # check wether a production tag exists on the release branch for the commit
    # sha1
    execute_process(
        COMMAND ${GIT_EXECUTABLE} tag --list 'version-*' --contains
                ${git_commit}
        WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
        OUTPUT_VARIABLE _release_has_tag
        ERROR_QUIET OUTPUT_STRIP_TRAILING_WHITESPACE)

    if("${_commit_in_release}" STREQUAL "")

        message_color(
            WARNING
            "GIT hash does not exist in release branch:\n\t===> this is a development version"
        )

    else()
        message_color(INFO "GIT hash exists in release branch")

        if("${_release_has_tag}" STREQUAL "")

            message_color(
                WARNING
                "GIT hash exists in branch release but does not have tag with pattern 'version-*':\n\t===> this is a development version"
            )

        else()
            message_color(
                OK
                "GIT hash has a 'version-*' tag:\n\t===> this is a production version"
            )
        endif()

    endif()

else()
    message_color(FATAL_ERROR "GIT not found")
endif()

# ##############################################################################
# Singularity recipes and images
# ##############################################################################

# working directory to build the container recipes and images
add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/containerWorkdir.done
    COMMAND ${CMAKE_COMMAND} -E echo "create containerWorkdir/"
    COMMAND ${CMAKE_COMMAND} -E copy_directory ${CMAKE_SOURCE_DIR}/recipes
            ${CMAKE_BINARY_DIR}/containerWorkdir/recipes
    COMMAND ${CMAKE_COMMAND} -E copy_directory ${CMAKE_BINARY_DIR}/nextflowConf
            ${CMAKE_BINARY_DIR}/containerWorkdir/conf/
    COMMAND ${CMAKE_COMMAND} -E copy
            ${CMAKE_SOURCE_DIR}/utils/install/nextflow.config
            ${CMAKE_BINARY_DIR}/containerWorkdir/
    COMMAND ${CMAKE_COMMAND} -E copy_directory ${CMAKE_SOURCE_DIR}/conf
            ${CMAKE_BINARY_DIR}/containerWorkdir/conf
    COMMAND ${CMAKE_COMMAND} -E copy
            ${CMAKE_SOURCE_DIR}/utils/install/singularity.nf
            ${CMAKE_BINARY_DIR}/containerWorkdir
    COMMAND ${CMAKE_COMMAND} -E copy_directory ${CMAKE_SOURCE_DIR}/modules
            ${CMAKE_BINARY_DIR}/containerWorkdir/modules
    COMMAND ${CMAKE_COMMAND} -E touch
            "${CMAKE_BINARY_DIR}/containerWorkdir.done"
    DEPENDS ${CMAKE_SOURCE_DIR}/recipes/*
    DEPENDS ${CMAKE_SOURCE_DIR}/conf/*
    DEPENDS ${CMAKE_SOURCE_DIR}/modules/*
    DEPENDS ${CMAKE_SOURCE_DIR}/utils/install/singularity.nf
    DEPENDS ${CMAKE_SOURCE_DIR}/utils/install/nextflow.config
    DEPENDS ${CMAKE_SOURCE_DIR}/utils/install/docker.nf)

# generate config (singularity, conda,multiconda, etc.)
add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/containerWorkdir/outputConfig.done
    COMMAND ${CMAKE_COMMAND} -E echo "Build singularity recipe"
    COMMAND ${CMAKE_COMMAND} -E copy
            ${CMAKE_SOURCE_DIR}/utils/install/singularity.nf
            ${CMAKE_BINARY_DIR}/containerWorkdir
    COMMAND
        ${NEXTFLOW_EXECUTABLE} run singularity.nf --buildSingularityConfig true
        -with-report --gitCommit ${git_commit} --gitUrl ${git_url}
    COMMAND ${CMAKE_COMMAND} -E touch "outputConfig.done"
    WORKING_DIRECTORY "${CMAKE_BINARY_DIR}/containerWorkdir"
    DEPENDS ${CMAKE_BINARY_DIR}/containerWorkdir.done)

# generate singularity recipes
add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/containerWorkdir/deffiles.done
    COMMAND ${CMAKE_COMMAND} -E echo "Build singularity recipe"
    COMMAND ${CMAKE_COMMAND} -E copy
            ${CMAKE_SOURCE_DIR}/utils/install/singularity.nf
            ${CMAKE_BINARY_DIR}/containerWorkdir
    COMMAND
        ${NEXTFLOW_EXECUTABLE} run singularity.nf --buildSingularityRecipes true
        -with-report --gitCommit ${git_commit} --gitUrl ${git_url}
    COMMAND ${CMAKE_COMMAND} -E touch "deffiles.done"
    WORKING_DIRECTORY "${CMAKE_BINARY_DIR}/containerWorkdir"
    DEPENDS ${CMAKE_BINARY_DIR}/containerWorkdir.done)

# allows the build of the recipes with "make build_singularity_recipes"
add_custom_target(
    build_singularity_recipes
    COMMAND ${CMAKE_COMMAND} -E echo "Build singularity recipe"
    DEPENDS ${CMAKE_BINARY_DIR}/containerWorkdir/deffiles.done)

# generate singularity recipes and images
add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/containerWorkdir/singularityImages.done
    COMMAND ${CMAKE_COMMAND} -E echo "Build singularity recipes and images"
    COMMAND ${CMAKE_COMMAND} -E copy
            ${CMAKE_SOURCE_DIR}/utils/install/singularity.nf
            ${CMAKE_BINARY_DIR}/containerWorkdir
    COMMAND
        ${NEXTFLOW_EXECUTABLE} run singularity.nf --buildSingularityImages true
        -with-report --gitCommit ${git_commit} --gitUrl ${git_url}
    COMMAND ${CMAKE_COMMAND} -E touch "singularityImages.done"
    WORKING_DIRECTORY "${CMAKE_BINARY_DIR}/containerWorkdir"
    DEPENDS ${CMAKE_BINARY_DIR}/containerWorkdir.done)

# allows the build of the recipes and images with "make
# build_singularity_images"
add_custom_target(
    build_singularity_images
    COMMAND ${CMAKE_COMMAND} -E echo "Build singularity recipes and images"
    DEPENDS ${CMAKE_BINARY_DIR}/containerWorkdir/singularityImages.done)

if(ap_install_singularity_recipes)
    message_color(INFO "Singularity recipes will be installed")

    add_custom_target(
        install_singularity_recipes ALL
        DEPENDS ${CMAKE_BINARY_DIR}/containerWorkdir/deffiles.done)

    install(DIRECTORY "${CMAKE_BINARY_DIR}/containerWorkdir/deffiles/"
            DESTINATION "${CMAKE_INSTALL_PREFIX}/containers/deffiles")
endif()

if(ap_install_singularity_images)
    message_color(INFO "Singularity recipes and images will be installed")

    add_custom_target(
        install_singularity_images ALL
        DEPENDS ${CMAKE_BINARY_DIR}/containerWorkdir/singularityImages.done)

    install(DIRECTORY "${CMAKE_BINARY_DIR}/containerWorkdir/deffiles/"
            DESTINATION "${CMAKE_INSTALL_PREFIX}/containers/deffiles")

    install(DIRECTORY "${CMAKE_BINARY_DIR}/containerWorkdir/singularityImages/"
            DESTINATION "${CMAKE_INSTALL_PREFIX}/containers/singularityImages")

endif()

add_custom_target(
    install_singularity_config ALL
    DEPENDS ${CMAKE_BINARY_DIR}/containerWorkdir/outputConfig.done)

install(
    DIRECTORY "${CMAKE_BINARY_DIR}/containerWorkdir/outputConfig/"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/conf"
    FILES_MATCHING
    PATTERN "*.config")

add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/pathDirectories.done
    COMMAND
        ${CMAKE_COMMAND}
        -Dpath_link_file=${CMAKE_BINARY_DIR}/containerWorkdir/outputConfig/pathLink.txt
        -Dpath_link_dir=${CMAKE_BINARY_DIR}/pathDirectories -P
        ${CMAKE_SOURCE_DIR}/utils/cmake/createPathDirectories.cmake
    DEPENDS ${CMAKE_BINARY_DIR}/containerWorkdir/outputConfig.done)

add_custom_target(install_path_directories ALL
                  DEPENDS ${CMAKE_BINARY_DIR}/pathDirectories.done)

install(DIRECTORY ${CMAKE_BINARY_DIR}/pathDirectories/
        DESTINATION ${CMAKE_INSTALL_PREFIX}/path)
