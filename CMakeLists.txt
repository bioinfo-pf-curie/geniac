cmake_minimum_required(VERSION 3.10.2)

project(analysis_pipeline LANGUAGES NONE)

set(CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/utils/cmake;${CMAKE_MODULE_PATH}")
set(CMAKE_BUILD_TYPE Release)

# force out-of-source build
if(${CMAKE_SOURCE_DIR} STREQUAL ${CMAKE_BINARY_DIR})
        message(
                FATAL_ERROR
                        "In-source builds not allowed.
		Please make a new directory (called a build directory) and run CMake from there.
		You may need to remove CMakeCache.txt.")
endif()

include("utils/cmake/utils.cmake")

# option(ap_use_containers "Allow the usage of singularity images (profile
# Containers)" ON) option(ap_use_toolspath "Allow the usage of tools installed
# in existing directories (profile toolsPath)" OFF) option(ap_docker_recipes
# "Generate Dockerfiles" OFF) option(ap_singularity_recipes "Generate
# Singularity def files" OFF)
set(ap_install_singularity_recipes
    "OFF"
    CACHE BOOL "Generate and install singularity def files")

set(ap_install_singularity_images
    "OFF"
    CACHE BOOL "Generate and install Singularity def files and images")

set(ap_conda_recipes_path "recipes/conda")

find_package(Git 2.0)
find_package(Nextflow 19.0)
find_package(Singularity 3.0)
find_package(Docker 18.0)

if(GIT_FOUND)
        message_color(OK "Git found")
else()
        message_color(WARNING "Git not found")
endif()

if(NEXTFLOW_FOUND)
        message_color(OK "Nextflow found")
else()
        message_color(WARNING "Nextflow not found")
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
# GIT INFORMATION
# ##############################################################################

if(NOT IS_DIRECTORY ${CMAKE_SOURCE_DIR}/.git)
        message_color(ERROR "Source directory is not a git repository")
endif()

if(GIT_FOUND)

        execute_process(
                COMMAND ${GIT_EXECUTABLE} rev-parse --short HEAD
                WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
                OUTPUT_VARIABLE _build_version
                ERROR_QUIET OUTPUT_STRIP_TRAILING_WHITESPACE)

        message(STATUS "GIT hash: ${_build_version}")

        execute_process(
                COMMAND ${GIT_EXECUTABLE} remote get-url origin
                WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
                OUTPUT_VARIABLE _git_repo_name
                ERROR_QUIET OUTPUT_STRIP_TRAILING_WHITESPACE)

        string(REGEX REPLACE ".*/" "" _git_repo_name ${_git_repo_name})
        string(REGEX REPLACE ".git$" "" _git_repo_name ${_git_repo_name})

        message(STATUS "GIT repository name: ${_git_repo_name}")

        execute_process(
                COMMAND ${GIT_EXECUTABLE} branch release --contains
                        ${_build_version}
                WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
                OUTPUT_VARIABLE _devel_version
                ERROR_QUIET OUTPUT_STRIP_TRAILING_WHITESPACE)

        if(${_devel_version})
                message_color(INFO "GIT hash exists in release branch")
        else()
                message_color(
                        WARNING
                        "GIT hash does not exist in release branch: this is a development version"
                )
        endif()
        # string(REGEX REPLACE ".*/" ""  _devel_version ${_devel_version})

        message_color(INFO "GIT repository on master: ${_devel_version}")

else()
        message_color(ERROR "GIT not found")
endif()

# ##############################################################################
# Singularity recipes and images
# ##############################################################################

if(SINGULARITY_FOUND AND NEXTFLOW_FOUND)

        # working directory to build the container recipes and images
        add_custom_command(
                OUTPUT ${CMAKE_BINARY_DIR}/containerWordir
                COMMAND ${CMAKE_COMMAND} -E copy_directory
                        ${CMAKE_SOURCE_DIR}/${ap_conda_recipes_path}
                        ${CMAKE_BINARY_DIR}/containerWordir/recipes/conda
                COMMAND ${CMAKE_COMMAND} -E copy_directory
                        ${CMAKE_BINARY_DIR}/nextflow_conf
                        ${CMAKE_BINARY_DIR}/containerWordir/conf/
                COMMAND ${CMAKE_COMMAND} -E copy
                        ${CMAKE_SOURCE_DIR}/nextflow.config
                        ${CMAKE_BINARY_DIR}/containerWordir/
                COMMAND ${CMAKE_COMMAND} -E copy_directory
                        ${CMAKE_SOURCE_DIR}/conf
                        ${CMAKE_BINARY_DIR}/containerWordir/conf
                COMMAND ${CMAKE_COMMAND} -E copy
                        ${CMAKE_SOURCE_DIR}/utils/install/singularity.nf
                        ${CMAKE_BINARY_DIR}/containerWordir)

        # generate singularity recipes
        add_custom_command(
                OUTPUT ${CMAKE_BINARY_DIR}/containerWordir/deffiles
                COMMAND ${CMAKE_COMMAND} -E echo "Build singularity recipe"
                COMMAND ${CMAKE_COMMAND} -E copy
                        ${CMAKE_SOURCE_DIR}/utils/install/singularity.nf
                        ${CMAKE_BINARY_DIR}/containerWordir
                COMMAND ${NEXTFLOW_EXECUTABLE} run singularity.nf
                        --buildSingularityImages false
                WORKING_DIRECTORY "${CMAKE_BINARY_DIR}/containerWordir"
                DEPENDS containerWordir)
        
	# allows the build of the recipes with "make build_singularity_recipes"
	add_custom_target(
                build_singularity_recipes
		COMMAND ${CMAKE_COMMAND} -E echo "Build singularity recipe"
                COMMAND ${CMAKE_COMMAND} -E copy
                        ${CMAKE_SOURCE_DIR}/utils/install/singularity.nf
                        ${CMAKE_BINARY_DIR}/containerWordir
                COMMAND ${NEXTFLOW_EXECUTABLE} run singularity.nf
                        --buildSingularityImages false
                WORKING_DIRECTORY "${CMAKE_BINARY_DIR}/containerWordir"
                DEPENDS containerWordir)

	# generate singularity recipes and images
        add_custom_command(
                OUTPUT ${CMAKE_BINARY_DIR}/containerWordir/singularityImages
                COMMAND ${CMAKE_COMMAND} -E echo "Build singularity recipe"
                COMMAND ${CMAKE_COMMAND} -E copy
                        ${CMAKE_SOURCE_DIR}/utils/install/singularity.nf
                        ${CMAKE_BINARY_DIR}/containerWordir
                COMMAND ${NEXTFLOW_EXECUTABLE} run singularity.nf
                        --buildSingularityImages true
                WORKING_DIRECTORY "${CMAKE_BINARY_DIR}/containerWordir"
                DEPENDS containerWordir)

	# allows the build of the recipes and images with "make build_singularity_images"
	add_custom_target(
                build_singularity_images
		COMMAND ${CMAKE_COMMAND} -E echo "Build singularity recipe"
                COMMAND ${CMAKE_COMMAND} -E copy
                        ${CMAKE_SOURCE_DIR}/utils/install/singularity.nf
                        ${CMAKE_BINARY_DIR}/containerWordir
                COMMAND ${NEXTFLOW_EXECUTABLE} run singularity.nf
                        --buildSingularityImages true
                WORKING_DIRECTORY "${CMAKE_BINARY_DIR}/containerWordir"
                DEPENDS containerWordir)

        if(ap_install_singularity_recipes)
                message_color(INFO "Singularity recipes will be installed")

                add_custom_target(
                        install_singularity_recipes ALL
                        DEPENDS ${CMAKE_BINARY_DIR}/containerWordir/deffiles)

                install(
                        DIRECTORY
                                "${CMAKE_BINARY_DIR}/containerWordir/deffiles/"
                        DESTINATION
                                "${CMAKE_INSTALL_PREFIX}/containers/deffiles")
        endif()

        if(ap_install_singularity_images)
                message_color(INFO "Singularity images will be installed")

                add_custom_target(
                        install_singularity_images ALL
                        DEPENDS
                                ${CMAKE_BINARY_DIR}/containerWordir/singularityImages
                )

                install(
                        DIRECTORY
                                "${CMAKE_BINARY_DIR}/containerWordir/deffiles/"
                        DESTINATION
                                "${CMAKE_INSTALL_PREFIX}/containers/deffiles")

                install(
                        DIRECTORY
                                "${CMAKE_BINARY_DIR}/containerWordir/singularityImages/"
                        DESTINATION
                                "${CMAKE_INSTALL_PREFIX}/containers/singularityImages"
                )

        endif()

endif()

install(
        DIRECTORY ${CMAKE_SOURCE_DIR}/
        DESTINATION ${CMAKE_INSTALL_PREFIX}
        USE_SOURCE_PERMISSIONS
        PATTERN "conf/templates" EXCLUDE
        PATTERN ".git*" EXCLUDE
        PATTERN "CMakeLists.txt" EXCLUDE
        PATTERN "*.example" EXCLUDE
        PATTERN "utils/" EXCLUDE)

add_subdirectory(conf/templates)
