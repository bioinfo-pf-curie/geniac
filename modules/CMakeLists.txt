include(ExternalProject)

ExternalProject_Add(
        helloworld
        SOURCE_DIR ${CMAKE_SOURCE_DIR}/modules/helloworld
        CMAKE_ARGS
                -DCMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX}/bin
                -Dap_singularity_image_path=${singularity_destination_path})

