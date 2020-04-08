# ##############################################################################
# Check that options match requirement
# ##############################################################################

if(ap_install_singularity_images)

    if(NOT NEXTFLOW_FOUND OR NOT SINGULARITY_FOUND)
        message_color(
            FATAL_ERROR
            "Both singularity and nextflow are required with options ap_install_singularity_images
			or ap_install_singularity_recipes set to ON ")
    else()

        if(ap_install_singularity_images)
            message_color(
                WARNING
                "ap_install_singularity_images is ON: root privilege will be required during make step"
            )
        endif()

    endif()

endif()

if(ap_install_docker_images)

    if(NOT NEXTFLOW_FOUND OR NOT DOCKER_FOUND)
        message_color(
            FATAL_ERROR
            "Both docker and nextflow are required with options ap_install_singularity_images
					or ap_install_singularity_recipes set to ON ")

    else()

        if(ap_install_docker_images)
            message_color(
                WARNING
                "ap_install_docker_images is ON: root privilege will be required during make step"
            )
        endif()
    endif()

endif()

if(ap_use_singularity_image_link AND ap_install_singularity_images)
    message_color(
        FATAL_ERROR
        "Both options ap_use_singularity_image_link and ap_install_singularity_images cannot be set to ON at the same time.\n\tEither ap_use_singularity_image_link is ON and a symlink to existing images directory must be provided,\n\tor ap_install_singularity_images is ON and images will be built and installed."
    )
endif()

# check that the variable ap_use_singularity_image_link is a boolean
if(NOT (${ap_use_singularity_image_link} STREQUAL ON OR ${ap_use_singularity_image_link} STREQUAL OFF))

    message_color(
        FATAL_ERROR
        "ap_use_singularity_image_link should be either ON or OFF (boolean variable)"
    )
endif()

if(ap_use_singularity_image_link)
    if(NOT IS_ABSOLUTE ${ap_singularity_image_path})
        message_color(FATAL_ERROR
                      "ap_singularity_image_path must be an absolute path.\n\tThe current value is invalid: \n\t'${ap_singularity_image_path}'. \n\tProvide a valid path with -Dap_singularity_image_path option")
    endif()

    if(IS_DIRECTORY ${ap_singularity_image_path})
        message_color(
            OK "ap_singularity_image_path ${ap_singularity_image_path} exists")
    else()
        message_color(
            WARNING
            "ap_singularity_image_path ${ap_singularity_image_path} does not exist"
        )
    endif()
    install(
        CODE "execute_process(
        COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_INSTALL_PREFIX}/containers
        COMMAND ${CMAKE_COMMAND} -E create_symlink ${ap_singularity_image_path} ${CMAKE_INSTALL_PREFIX}/${singularity_image_dir})"
    )
endif()

# check that the variable ap_use_annotation_link is a boolean
if(NOT (${ap_use_annotation_link} STREQUAL ON OR ${ap_use_annotation_link} STREQUAL OFF))

    message_color(
        FATAL_ERROR
        "ap_use_annotation_link should be either ON or OFF (boolean variable)"
    )
endif()

if(ap_use_annotation_link)

    
    if(NOT IS_ABSOLUTE ${ap_annotation_path})
        message_color(
            FATAL_ERROR
            "ap_annotation_path must be an absolute path. \n\tThe current value is invalid: \n\t'${ap_annotation_path}'. \n\tProvide a valid path with -Dap_annotation_path option"
        )
    endif()

    if(IS_DIRECTORY ${ap_annotation_path})
        message_color(OK "ap_annotation_path ${ap_annotation_path} exists")
    else()
        message_color(WARNING
                      "ap_annotation_path ${ap_annotation_path} does not exist")
    endif()

    install(
        CODE "execute_process(
        COMMAND ${CMAKE_COMMAND} -E create_symlink ${ap_annotation_path} ${CMAKE_INSTALL_PREFIX}/annotations)"
    )
else()
    install(
        CODE "execute_process(
        COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_INSTALL_PREFIX}/annotations)"
    )
endif()

