# ##############################################################################
# Custom targets for tests
# ##############################################################################

set(profile_list "standard" "conda" "multiconda" "singularity" "docker" "path")

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
