# ##############################################################################
# GIT INFORMATION
# ##############################################################################

# This script retrieves information about the git repository.
# It will detect if the current version is in developement
# or a production release provided that. This will work only if
# the production version is tag with the prefix "version-".
#  /!\  Do not use this prefix is this is not a production version /!\ 

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


    execute_process(
        COMMAND bash "-c" "${GIT_EXECUTABLE} describe --tags --match 'version-*' --exact-match ${git_commit}"
        WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
        OUTPUT_VARIABLE _has_production_tag
        ERROR_QUIET OUTPUT_STRIP_TRAILING_WHITESPACE)


    if("${_has_production_tag}" STREQUAL "")

        message_color(
            WARNING
            "GIT hash does not have a production tag:\n\t===> this is a development version"
            )

        set(git_commit "${git_commit} / devel") # do not change this, the variable must contain "devel"
    else()
        message_color(
            OK
            "GIT hash has a 'version-*' tag:\n\t===> this is a production version"
            )
    endif()

else()
    message_color(FATAL_ERROR "GIT not found")
endif()

# fill the files with the git information
configure_file(${CMAKE_SOURCE_DIR}/main.nf ${CMAKE_BINARY_DIR}/git/main.nf
    @ONLY)
install(FILES ${CMAKE_BINARY_DIR}/git/main.nf
    DESTINATION ${CMAKE_INSTALL_PREFIX}/${pipeline_dir})

configure_file(${CMAKE_SOURCE_DIR}/nextflow.config
    ${CMAKE_BINARY_DIR}/git/nextflow.config @ONLY)
install(FILES ${CMAKE_BINARY_DIR}/git/nextflow.config
    DESTINATION ${CMAKE_INSTALL_PREFIX}/${pipeline_dir})
