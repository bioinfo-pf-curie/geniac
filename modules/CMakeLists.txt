include(ExternalProject)

# Test if some modules can be install
file(GLOB ap_module_list "${CMAKE_CURRENT_SOURCE_DIR}/*.sh")
list(LENGTH ap_module_list ap_module_number)

if(${ap_module_number} EQUAL 0)
    message_color(INFO "There is no module from source code to install")
else()
    message_color(INFO "Modules from source code will be installed")
    ExternalProject_Add(
        helloWorld
        SOURCE_DIR ${CMAKE_SOURCE_DIR}/modules/helloWorld
        CMAKE_ARGS
            -DCMAKE_INSTALL_PREFIX=${CMAKE_BINARY_DIR}/externalProject/bin)

    install(
        DIRECTORY ${CMAKE_BINARY_DIR}/externalProject/bin/
        DESTINATION ${CMAKE_INSTALL_PREFIX}/bin
        USE_SOURCE_PERMISSIONS)

endif()
