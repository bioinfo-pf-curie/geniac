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
    ExternalProject_Add(
        helloWorld
        SOURCE_DIR ${pipeline_source_dir}/modules/helloWorld
        CMAKE_ARGS
        -DCMAKE_INSTALL_PREFIX=${CMAKE_BINARY_DIR}/externalProject/bin)

    ### END >>> ExternalProject section
    ###########################################################################


    ###########################################################################
    # the code below should not be modified
    ###########################################################################

    # IMPORTANT: DESTINATION for install must always be ${CMAKE_INSTALL_PREFIX}/${pipeline_dir}/bin
    install(
        DIRECTORY ${CMAKE_BINARY_DIR}/externalProject/bin/
        DESTINATION ${CMAKE_INSTALL_PREFIX}/${pipeline_dir}/bin
        USE_SOURCE_PERMISSIONS)

endif()
