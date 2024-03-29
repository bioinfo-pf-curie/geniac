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
        FATAL_ERROR "In-source builds not allowed. Please make a new directory (called a build directory) and run CMake from there. You may need to remove CMakeCache.txt.")
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

# Test if some modules can be installed from source code
if(EXISTS ${pipeline_source_dir}/modules/fromSource/CMakeLists.txt)

    file(GLOB ap_module_list LIST_DIRECTORIES true "${pipeline_source_dir}/modules/fromSource")
    list(LENGTH ap_module_list ap_module_number)

    if(${ap_module_number} EQUAL 0)
      message_color(INFO "There is no module available: the directory ${pipeline_source_dir}/modules/fromSource does not have any folder.")
    else()
      add_subdirectory(${pipeline_source_dir}/modules/fromSource modules/fromSource)
      message_color(INFO "Modules from source code available in the directory ${pipeline_source_dir}/modules/fromSource will be installed.")
    endif()
else()
  message_color(INFO "There is no tool to be installed from source code.")

endif()

