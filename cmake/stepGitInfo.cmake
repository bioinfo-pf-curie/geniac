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

        set(git_commit "${git_commit} / devel")

    else()
        message_color(INFO "GIT hash exists in release branch")

        if("${_release_has_tag}" STREQUAL "")

            message_color(
                WARNING
                "GIT hash exists in branch release but does not have tag with pattern 'version-*':\n\t===> this is a development version"
            )

            set(git_commit "${git_commit} / devel")

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

# fill the files with the git information
configure_file(${CMAKE_SOURCE_DIR}/main.nf ${CMAKE_BINARY_DIR}/git/main.nf
               @ONLY)
install(FILES ${CMAKE_BINARY_DIR}/git/main.nf
        DESTINATION ${CMAKE_INSTALL_PREFIX}/${pipeline_dir})

configure_file(${CMAKE_SOURCE_DIR}/nextflow.config
               ${CMAKE_BINARY_DIR}/git/nextflow.config @ONLY)
install(FILES ${CMAKE_BINARY_DIR}/git/nextflow.config
        DESTINATION ${CMAKE_INSTALL_PREFIX}/${pipeline_dir})
