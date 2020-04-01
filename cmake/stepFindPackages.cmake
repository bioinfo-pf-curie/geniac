# ##############################################################################
# Find packages
# ##############################################################################

set(CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/utils/cmake;${CMAKE_MODULE_PATH}")

find_package(Git 2.0)
find_package(Nextflow 19.10)
find_package(Singularity 3.2)
find_package(Docker 18.0)

if(GIT_FOUND)
    message_color(OK "Git found")
else()
    message_color(WARNING "Git not found")
endif()

if(NEXTFLOW_FOUND)
    message_color(OK "Nextflow found")
else()
    message_color(FATAL_ERROR
                  "Nextflow not found. It is required during the build step.")
endif()

if(SINGULARITY_FOUND)
    message_color(OK "Singularity found")
else()
    message_color(WARNING "Singularity not found")
endif()

if(DOCKER_FOUND)
    message_color(OK "Docker found")
else()
    message_color(WARNING "Docker not found")
endif()

