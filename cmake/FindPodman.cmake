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
# ``PODMAN_EXECUTABLE``
#   Path to Podman command-line client.
# ``Podman_FOUND``, ``PODMAN_FOUND``
#   True if the Podman command-line client was found.
# ``PODMAN_VERSION_STRING``
#   The version of Podman found.
#
# Example usage:
#
# .. code-block:: cmake
#
#    find_package(Podman)
#    if(Podman_FOUND)
#      message("Podman found: ${PODMAN_EXECUTABLE}")
#    endif()

# Look for 'podman'
#
set(podman_names podman)
set(PODMAN_COMPATIBLE_VERSION FALSE)

# First search the PATH and specific locations.
find_program(PODMAN_EXECUTABLE
  NAMES ${podman_names}
  DOC "Podman command line client"
  )


mark_as_advanced(PODMAN_EXECUTABLE)

unset(podman_names)
unset(_podman_sourcetree_path)

if(PODMAN_EXECUTABLE)
  execute_process(COMMAND ${PODMAN_EXECUTABLE} --version
                  OUTPUT_VARIABLE podman_version
                  ERROR_QUIET
                  OUTPUT_STRIP_TRAILING_WHITESPACE)

  string(REGEX REPLACE ",.*$" "" podman_version "${podman_version}")

  if (podman_version MATCHES "^podman version [0-9]")
    string(REPLACE "podman version " "" PODMAN_VERSION_STRING "${podman_version}")
  endif()
  unset(podman_version)

  find_package_check_version("${PODMAN_VERSION_STRING}" PODMAN_COMPATIBLE_VERSION)
  if(PODMAN_COMPATIBLE_VERSION)
    message(STATUS "Found compatible Podman version: '${PODMAN_VERSION_STRING}'")
  else()
    message(STATUS "Found  unsuitable Podman version: '${PODMAN_VERSION_STRING}'")
  endif()

endif()

include( FindPackageHandleStandardArgs )


find_package_handle_standard_args(Podman
                                  REQUIRED_VARS PODMAN_EXECUTABLE PODMAN_COMPATIBLE_VERSION
                                  VERSION_VAR PODMAN_VERSION_STRING)
