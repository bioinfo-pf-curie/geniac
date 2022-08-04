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
# ``SINGULARITY_EXECUTABLE``
#   Path to Singularity command-line client.
# ``Singularity_FOUND``, ``SINGULARITY_FOUND``
#   True if the Singularity command-line client was found.
# ``SINGULARITY_VERSION_STRING``
#   The version of Singularity found.
#
# Example usage:
#
# .. code-block:: cmake
#
#    find_package(Singularity)
#    if(Singularity_FOUND)
#      message("Singularity found: ${SINGULARITY_EXECUTABLE}")
#    endif()

# Look for 'singularity'
#
set(singularity_names singularity)
set(SINGULARITY_COMPATIBLE_VERSION FALSE)

# First search the PATH and specific locations.
find_program(SINGULARITY_EXECUTABLE
  NAMES ${singularity_names}
  DOC "Singularity command line client"
  )


mark_as_advanced(SINGULARITY_EXECUTABLE)

unset(singularity_names)
unset(_singularity_sourcetree_path)

if(SINGULARITY_EXECUTABLE)
  execute_process(COMMAND ${SINGULARITY_EXECUTABLE} --version
                  OUTPUT_VARIABLE singularity_version
                  ERROR_QUIET
                  OUTPUT_STRIP_TRAILING_WHITESPACE)
  if (singularity_version MATCHES "^singularity version [0-9]")
    string(REPLACE "singularity version " "" SINGULARITY_VERSION_STRING "${singularity_version}")
  endif()
  if (singularity_version MATCHES "^singularity-ce version [0-9]")
    string(REPLACE "singularity-ce version " "" SINGULARITY_VERSION_STRING "${singularity_version}")
  endif()
  unset(singularity_version)

  find_package_check_version("${SINGULARITY_VERSION_STRING}" SINGULARITY_COMPATIBLE_VERSION)
  if(SINGULARITY_COMPATIBLE_VERSION)
    message(STATUS "Found compatible Singularity version: '${SINGULARITY_VERSION_STRING}'")
  else()
    message(STATUS "Found  unsuitable Singularity version: '${SINGULARITY_VERSION_STRING}'")
  endif()

endif()

include( FindPackageHandleStandardArgs )

find_package_handle_standard_args(Singularity
                                  REQUIRED_VARS SINGULARITY_EXECUTABLE SINGULARITY_COMPATIBLE_VERSION
                                  VERSION_VAR SINGULARITY_VERSION_STRING)
