cmake_minimum_required(VERSION 3.10.2)

project(analysis_pipeline LANGUAGES NONE)

set(CMAKE_BUILD_TYPE Release)

# ##############################################################################
# Include some functions
# ##############################################################################

include("cmake/functionColorMessage.cmake")

# ##############################################################################
# Force out-of-source build
# ##############################################################################

if(${CMAKE_SOURCE_DIR} STREQUAL ${CMAKE_BINARY_DIR})
    message(
        FATAL_ERROR
            "In-source builds not allowed.
		Please make a new directory (called a build directory) and run CMake from there.
		You may need to remove CMakeCache.txt.")
endif()

# ##############################################################################
# IMPORTANT: do not change the order of the following steps
# ##############################################################################

# ##############################################################################
# STEP 1
# ##############################################################################
# Set all the cmake variables including CACHE variables
# ##############################################################################

include("cmake/stepSetVariables.cmake")

# ##############################################################################
# STEP 2
# ##############################################################################
# Install the source code of the pipeline. Only usefull files for the execution
# of the pipeline are deployed
# ##############################################################################
# TODO: use explicit include instead of exclusion pattern
install(
    DIRECTORY ${pipeline_source_dir}/
    DESTINATION ${CMAKE_INSTALL_PREFIX}/${pipeline_dir}
    USE_SOURCE_PERMISSIONS
    PATTERN "environment.yml" EXCLUDE
    PATTERN "conf/templates" EXCLUDE
    PATTERN ".git*" EXCLUDE
    PATTERN "CMakeLists.txt" EXCLUDE
    PATTERN "*.example" EXCLUDE
    PATTERN "geniac" EXCLUDE
    PATTERN "work" EXCLUDE)

# ##############################################################################
# STEP 3
# ##############################################################################
# Provide the set of utilities to configure the installation of the pipeline
# ##############################################################################

add_subdirectory(cmake)

# ##############################################################################
# STEP 4
# ##############################################################################
# Install the pipeline dependencies available in the modules directorry if it
# exists
# ##############################################################################

if(EXISTS ${pipeline_source_dir}/modules/CMakeLists.txt)
    add_subdirectory(${pipeline_source_dir}/modules modules)
endif()
