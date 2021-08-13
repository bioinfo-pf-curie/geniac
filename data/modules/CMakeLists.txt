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


include(ExternalProject)

# Test if some modules can be install
file(GLOB ap_module_list "${CMAKE_CURRENT_SOURCE_DIR}/*.sh")
list(LENGTH ap_module_list ap_module_number)

if(${ap_module_number} EQUAL 0)
    message_color(INFO "There is no module from source code to install")
else()
    message_color(INFO "Modules from source code will be installed")


    ###########################################################################
    # Only modify the section below
    ###########################################################################
    ### BEGIN >>> ExternalProject section
    # ExternalProject_Add(
    #     helloWorld
    #     SOURCE_DIR ${pipeline_source_dir}/modules/helloWorld
    #     CMAKE_ARGS
    #     -DCMAKE_INSTALL_PREFIX=${CMAKE_BINARY_DIR}/externalProject/bin)

    ### END >>> ExternalProject section
    ###########################################################################


    ###########################################################################
    # the code below should not be modified
    ###########################################################################

    # IMPORTANT: DESTINATION for install must always be ${CMAKE_INSTALL_PREFIX}/${pipeline_dir}/bin
    install(
        DIRECTORY ${CMAKE_BINARY_DIR}/externalProject/bin/
        DESTINATION ${CMAKE_INSTALL_PREFIX}/${pipeline_dir}/bin/fromSource
        USE_SOURCE_PERMISSIONS)

endif()

