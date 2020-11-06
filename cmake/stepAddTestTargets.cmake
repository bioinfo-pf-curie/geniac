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


# ##############################################################################
# Custom targets for tests
# ##############################################################################

set(profile_list "standard" "conda" "multiconda" "singularity" "docker" "path" "multipath")

add_custom_target(
    myinstall
    COMMAND ${CMAKE_COMMAND} -E echo "Install"
    COMMAND ${CMAKE_COMMAND} --build . --target install
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR})

foreach(profile_i ${profile_list})

    add_custom_target(
        test_${profile_i}
        COMMAND ${CMAKE_COMMAND} -E echo "Start test profile ${profile_i}"
        COMMAND
            ${NEXTFLOW_EXECUTABLE} run main.nf -c conf/test.config -profile
            ${profile_i}
        WORKING_DIRECTORY ${CMAKE_INSTALL_PREFIX}/pipeline
        DEPENDS myinstall)

    add_custom_target(
        test_${profile_i}_cluster
        COMMAND ${CMAKE_COMMAND} -E echo "Start test profile ${profile_i}"
        COMMAND
            ${NEXTFLOW_EXECUTABLE} run main.nf -c conf/test.config -profile
            ${profile_i},cluster
        WORKING_DIRECTORY ${CMAKE_INSTALL_PREFIX}/pipeline
        DEPENDS myinstall)

endforeach()
