include(ExternalProject)

ExternalProject_Add(
        helloworld
        SOURCE_DIR ${CMAKE_SOURCE_DIR}/modules/helloworld
        CMAKE_ARGS
                -DCMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX}/bin)

