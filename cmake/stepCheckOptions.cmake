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
            "Both docker and nextflow are required with options ap_install_docker_images
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

if(ap_install_podman_images)

  if(NOT NEXTFLOW_FOUND OR NOT PODMAN_FOUND)
        message_color(
            FATAL_ERROR
            "Both podman and nextflow are required with options ap_install_podman_images
					or ap_install_singularity_recipes set to ON ")

    else()

        if(ap_install_podman_images)
            message_color(
                WARNING
                "ap_install_podman_images is ON: root privilege will be required during make step"
            )
        endif()
    endif()

endif()


if(NOT "${ap_singularity_image_path}" STREQUAL "")

    set(ap_use_singularity_image_link ON)
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
        COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_INSTALL_PREFIX}/containers)"
    )

    install(
        CODE "execute_process(
        COMMAND ${CMAKE_COMMAND} -E create_symlink ${ap_singularity_image_path} ${CMAKE_INSTALL_PREFIX}/${singularity_image_dir})"
    )

else()
    set(ap_use_singularity_image_link OFF)
endif()


if(ap_use_singularity_image_link AND ap_install_singularity_images)
    message_color(
        FATAL_ERROR
        "Both options ap_singularity_image_path and ap_install_singularity_images cannot be used at the same time.\n\tEither ap_singularity_image_path is used and a symlink to existing images directory must be provided,\n\tor ap_install_singularity_images is ON and images will be built and installed."
    )
endif()

if(NOT "${ap_annotation_path}" STREQUAL "")
    
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


if(NOT "${ap_docker_registry}" STREQUAL "")
  if(NOT "${ap_docker_registry}" MATCHES ".*/")
    message_color(ERROR "ap_docker_registry '${ap_docker_registry}' must end with '/'")
  endif()
endif()
  
if(NOT "${ap_linux_distro}" MATCHES ".*:.*")
  message_color(ERROR "ap_linux_distro '${ap_linux_distro}' must be formatted like 'distro:version' (e.g. almalinux:8.4).")
endif()
