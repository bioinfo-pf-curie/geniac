# CMakeLists files in this project can
# refer to the root source directory of the project as ${HELLO_SOURCE_DIR} and
# to the root binary directory of the project as ${HELLO_BINARY_DIR}.
cmake_minimum_required (VERSION 3.10.2)
project (analysis_pipeline LANGUAGES NONE)


set(CMAKE_BUILD_TYPE Release)

# force out-of-source build
if ( ${CMAKE_SOURCE_DIR} STREQUAL ${CMAKE_BINARY_DIR} )
        message(FATAL_ERROR "In-source builds not allowed.
        Please make a new directory (called a build directory) and run CMake from there.
        You may need to remove CMakeCache.txt." )
endif()

if(NOT WIN32)
  string(ASCII 27 Esc)
  set(ColourReset "${Esc}[m")
  set(ColourBold  "${Esc}[1m")
  set(Red         "${Esc}[31m")
  set(Green       "${Esc}[32m")
  set(Yellow      "${Esc}[33m")
  set(Blue        "${Esc}[34m")
  set(Magenta     "${Esc}[35m")
  set(Cyan        "${Esc}[36m")
  set(White       "${Esc}[37m")
  set(BoldRed     "${Esc}[1;31m")
  set(BoldGreen   "${Esc}[1;32m")
  set(BoldYellow  "${Esc}[1;33m")
  set(BoldBlue    "${Esc}[1;34m")
  set(BoldMagenta "${Esc}[1;35m")
  set(BoldCyan    "${Esc}[1;36m")
  set(BoldWhite   "${Esc}[1;37m")
endif()


option(ap_use_containers "Allow the usage of singularity images (profile Containers)" ON)
option(ap_use_toolspath "Allow the usage of tools installed in existing directories (profile toolsPath) " OFF)


find_package(Git 1.8)

if(GIT_FOUND)
  execute_process(
    COMMAND ${GIT_EXECUTABLE} rev-parse --short HEAD
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
    OUTPUT_VARIABLE _build_version
    ERROR_QUIET
    OUTPUT_STRIP_TRAILING_WHITESPACE
  )
  message( STATUS "GIT hash: ${_build_version}")

  execute_process(
    COMMAND ${GIT_EXECUTABLE} remote get-url origin
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
    OUTPUT_VARIABLE _git_repo_name
    ERROR_QUIET
    OUTPUT_STRIP_TRAILING_WHITESPACE
  )

  string(REGEX REPLACE ".*/" ""  _git_repo_name ${_git_repo_name})
  string(REGEX REPLACE ".git$" ""  _git_repo_name ${_git_repo_name})

  message( STATUS "GIT repository name: ${_git_repo_name}")

  execute_process(
    COMMAND ${GIT_EXECUTABLE} branch release --contains ${_build_version}
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
    OUTPUT_VARIABLE _devel_version
    ERROR_QUIET
    OUTPUT_STRIP_TRAILING_WHITESPACE
  )

  if(${_devel_version})
    message( STATUS "GIT hash exists in release branch")
  else()
    message( STATUS "GIT hash does not exist in release branch: this is a development version")
  endif()
  #string(REGEX REPLACE ".*/" ""  _devel_version ${_devel_version})

  message( STATUS "GIT repository on master: a${_devel_version}a")

else()
  message(STATUS "GIT not found")
endif()

install(DIRECTORY pipeline/ DESTINATION ${CMAKE_INSTALL_PREFIX} USE_SOURCE_PERMISSIONS PATTERN "conf/templates" EXCLUDE PATTERN ".git*" EXCLUDE PATTERN "CMakeLists.txt" EXCLUDE PATTERN "*.example" EXCLUDE PATTERN)

add_subdirectory (pipeline/conf/templates)

