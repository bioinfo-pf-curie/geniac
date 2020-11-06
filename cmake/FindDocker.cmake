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



# The module defines the following variables:
#
# ``DOCKER_EXECUTABLE``
#   Path to Docker command-line client.
# ``Docker_FOUND``, ``DOCKER_FOUND``
#   True if the Docker command-line client was found.
# ``DOCKER_VERSION_STRING``
#   The version of Docker found.
#
# Example usage:
#
# .. code-block:: cmake
#
#    find_package(Docker)
#    if(Docker_FOUND)
#      message("Docker found: ${DOCKER_EXECUTABLE}")
#    endif()

# Look for 'docker'
#
set(docker_names docker)


# First search the PATH and specific locations.
find_program(DOCKER_EXECUTABLE
  NAMES ${docker_names}
  DOC "Docker command line client"
  )


mark_as_advanced(DOCKER_EXECUTABLE)

unset(docker_names)
unset(_docker_sourcetree_path)

if(DOCKER_EXECUTABLE)
  execute_process(COMMAND ${DOCKER_EXECUTABLE} --version
                  OUTPUT_VARIABLE docker_version
                  ERROR_QUIET
                  OUTPUT_STRIP_TRAILING_WHITESPACE)

  string(REGEX REPLACE ",.*$" "" docker_version "${docker_version}")

  if (docker_version MATCHES "^Docker version [0-9]")
    string(REPLACE "Docker version " "" DOCKER_VERSION_STRING "${docker_version}")
  endif()
  unset(docker_version)
endif()

include( FindPackageHandleStandardArgs )

find_package_handle_standard_args(Docker
                                  REQUIRED_VARS DOCKER_EXECUTABLE
                                  VERSION_VAR DOCKER_VERSION_STRING)
