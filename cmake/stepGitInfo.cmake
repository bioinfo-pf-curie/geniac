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
# GIT INFORMATION
# ##############################################################################

# This script retrieves information about the git repository.
# It will detect if the current version is in developement
# or a production release provided that. This will work only if
# the production version is tag with the prefix "version-".
#  /!\  Do not use this prefix is this is not a production version /!\ 



if(GIT_FOUND)

    # test if the source directory is a git repository
    execute_process(
        COMMAND bash "-c" "${GIT_EXECUTABLE} rev-parse --is-inside-work-tree"
        WORKING_DIRECTORY "${pipeline_source_dir}"
        OUTPUT_VARIABLE _is_git_repo
        ERROR_QUIET OUTPUT_STRIP_TRAILING_WHITESPACE)

      if(NOT "${_is_git_repo}" STREQUAL "true")
        message_color(FATAL_ERROR "Source directory is not a git repository")
      endif()

    # extract the commid id
    execute_process(
        COMMAND ${GIT_EXECUTABLE} rev-parse HEAD
        WORKING_DIRECTORY "${pipeline_source_dir}"
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
        WORKING_DIRECTORY "${pipeline_source_dir}"
        OUTPUT_VARIABLE git_url
        ERROR_QUIET OUTPUT_STRIP_TRAILING_WHITESPACE)

    string(REGEX REPLACE ".*/" "" git_repo_name ${git_url})
    string(REGEX REPLACE ".git$" "" git_repo_name ${git_repo_name})

    message(STATUS "GIT repository name: ${git_repo_name}")

    execute_process(
        COMMAND bash "-c" "${GIT_EXECUTABLE} describe --tags --match 'version-[0-9].[0-9].[0-9]' --match 'v[0-9].[0-9].[0-9]' --exact-match ${git_commit}"
        WORKING_DIRECTORY "${pipeline_source_dir}"
        OUTPUT_VARIABLE _has_production_tag
        ERROR_QUIET OUTPUT_STRIP_TRAILING_WHITESPACE)


    if("${_has_production_tag}" STREQUAL "")

        message_color(
            WARNING
            "GIT hash does not have a production tag:\n\t===> this is a development version"
            )

        set(git_commit "commit:${git_commit}/devel") # do not change this, the variable must contain "devel"
    else()
        message_color(
            OK
            "GIT hash has a 'version-x.y.x' or 'vx.y.z' tag pattern:\n\t===> this is a production version with commit ${git_commit} ${_has_production_tag}"
            )
        set(git_commit "tag:${_has_production_tag}-commit:${git_commit}") # do not change this, the variable must contain "devel"
    endif()

else()
    message_color(FATAL_ERROR "GIT not found")
endif()

# fill the files with the git information
configure_file(${pipeline_source_dir}/main.nf ${CMAKE_BINARY_DIR}/git/main.nf
    @ONLY)
install(FILES ${CMAKE_BINARY_DIR}/git/main.nf
    DESTINATION ${CMAKE_INSTALL_PREFIX}/${pipeline_dir})

configure_file(${pipeline_source_dir}/nextflow.config
    ${CMAKE_BINARY_DIR}/git/nextflow.config @ONLY)
install(FILES ${CMAKE_BINARY_DIR}/git/nextflow.config
    DESTINATION ${CMAKE_INSTALL_PREFIX}/${pipeline_dir})
