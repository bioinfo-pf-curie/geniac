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
# ``APPTAINER_EXECUTABLE``
#   Path to Apptainer command-line client.
# ``Apptainer_FOUND``, ``APPTAINER_FOUND``
#   True if the Apptainer command-line client was found.
# ``APPTAINER_VERSION_STRING``
#   The version of Apptainer found.
#
# Example usage:
#
# .. code-block:: cmake
#
#    find_package(Apptainer)
#    if(Apptainer_FOUND)
#      message("Apptainer found: ${APPTAINER_EXECUTABLE}")
#    endif()

# Look for 'apptainer'
#

# below is written singularity on purpose
set(apptainer_names singularity)
set(APPTAINER_COMPATIBLE_VERSION FALSE)

# First search the PATH and specific locations.
find_program(APPTAINER_EXECUTABLE
  NAMES ${apptainer_names}
  DOC "Apptainer command line client"
  )


mark_as_advanced(APPTAINER_EXECUTABLE)

unset(apptainer_names)
unset(_apptainer_sourcetree_path)

if(APPTAINER_EXECUTABLE)
  execute_process(COMMAND ${APPTAINER_EXECUTABLE} --version
                  OUTPUT_VARIABLE apptainer_version
                  ERROR_QUIET
                  OUTPUT_STRIP_TRAILING_WHITESPACE)
  if (apptainer_version MATCHES "^apptainer version [0-9]")
    string(REPLACE "apptainer version " "" APPTAINER_VERSION_STRING "${apptainer_version}")
  endif()
  unset(apptainer_version)

  find_package_check_version("${APPTAINER_VERSION_STRING}" APPTAINER_COMPATIBLE_VERSION)
  if(APPTAINER_COMPATIBLE_VERSION)
    message(STATUS "Found compatible Apptainer version: '${APPTAINER_VERSION_STRING}'")
  else()
    message(STATUS "Found  unsuitable Apptainer version: '${APPTAINER_VERSION_STRING}'")
  endif()

endif()

include( FindPackageHandleStandardArgs )


find_package_handle_standard_args(Apptainer
                                  REQUIRED_VARS APPTAINER_EXECUTABLE APPTAINER_COMPATIBLE_VERSION
                                  VERSION_VAR APPTAINER_VERSION_STRING)
