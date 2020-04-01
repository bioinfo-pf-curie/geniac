
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
  unset(singularity_version)
endif()

include( FindPackageHandleStandardArgs )

find_package_handle_standard_args(Singularity
                                  REQUIRED_VARS SINGULARITY_EXECUTABLE
                                  VERSION_VAR SINGULARITY_VERSION_STRING)
