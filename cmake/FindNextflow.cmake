
# The module defines the following variables:
#
# ``NEXTFLOW_EXECUTABLE``
#   Path to Nextflow command-line client.
# ``Nextflow_FOUND``, ``NEXTFLOW_FOUND``
#   True if the Nextflow command-line client was found.
# ``NEXTFLOW_VERSION_STRING``
#   The version of Nextflow found.
#
# Example usage:
#
# .. code-block:: cmake
#
#    find_package(Nextflow)
#    if(Nextflow_FOUND)
#      message("Nextflow found: ${NEXTFLOW_EXECUTABLE}")
#    endif()

# Look for 'nextflow'
#
set(nextflow_names nextflow)


# First search the PATH and specific locations.
find_program(NEXTFLOW_EXECUTABLE
  NAMES ${nextflow_names}
  DOC "Nextflow command line client"
  )


mark_as_advanced(NEXTFLOW_EXECUTABLE)

unset(nextflow_names)
unset(_nextflow_sourcetree_path)

if(NEXTFLOW_EXECUTABLE)
  execute_process(COMMAND ${NEXTFLOW_EXECUTABLE} -version
                  OUTPUT_VARIABLE nextflow_version
                  ERROR_QUIET
                  OUTPUT_STRIP_TRAILING_WHITESPACE)

  string(REGEX REPLACE ".*version " "version" nextflow_version "${nextflow_version}")
  string(REGEX REPLACE " .*$" "" nextflow_version "${nextflow_version}")

  if (nextflow_version MATCHES "^version[0-9]")
    string(REPLACE "version" "" NEXTFLOW_VERSION_STRING "${nextflow_version}")
  endif()
  unset(nextflow_version)
endif()

include( FindPackageHandleStandardArgs )

find_package_handle_standard_args(Nextflow
                                  REQUIRED_VARS NEXTFLOW_EXECUTABLE
                                  VERSION_VAR NEXTFLOW_VERSION_STRING)
