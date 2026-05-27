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

if(ap_install_singularity_images AND ap_install_singularity_images_from_registry)
    message_color(
        FATAL_ERROR
				"Choise either ap_install_singularity_images or ap_install_singularity_images_from_registry, but not both at the same time 
  or ap_install_singularity_recipes set to ON ")
endif()

if(ap_install_singularity_images_from_registry AND NOT ap_install_singularity_recipes)
    message_color(
			FATAL_ERROR "In order to build the singularity images fom a registry, you must also enable the option -Dap_install_singularity_recipes. This is necessary to obtain the list of all the containers and their recipes."
  )
endif()

if(ap_install_singularity_images_from_registry)
	if(NOT ap_install_docker_recipes AND NOT ap_install_podman_recipes)
    message_color(
			FATAL_ERROR "In order to build the singularity images fom a registry, you must also enable the option -Dap_install_docker_recipes or -Dap_install_podman_recipes. This is necessary to obtain the list of all the sha256sum which is the tag on the registry." )
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

if(ap_push_images)
	  if(NOT ap_install_docker_images AND NOT ap_install_podman_images)
        message_color(FATAL_ERROR
					"ap_push_images is set to ON but both ap_install_docker_images and ap_install_podman_images are set to OFF. You must set to ON either ap_install_docker_images or ap_install_podman_images usch that you can first build the images and push them on a registry.")
	  endif()

		if(ap_docker_registry_push_repo STREQUAL "")
        message_color(FATAL_ERROR
					"ap_push_images is set to ON but no registry has been provided. You must set ap_docker_registry_push_repo with the name of your registry.")
		endif()
    # The option below will be pass to nextflow
		set(push_images_nfx "true")
else()
		set(push_images_nfx "false")
endif()

if(NOT "${ap_singularity_image_path}" STREQUAL "")

    set(ap_use_singularity_image_link ON)
    if(NOT IS_ABSOLUTE ${ap_singularity_image_path})
        message_color(FATAL_ERROR
                      "ap_singularity_image_path must be an absolute path.\n\tThe current value is invalid: \n\t${ap_singularity_image_path}. \n\tProvide a valid path with -Dap_singularity_image_path option")
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
            "ap_annotation_path must be an absolute path. \n\tThe current value is invalid: \n\t${ap_annotation_path}. \n\tProvide a valid path with -Dap_annotation_path option"
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
    message_color(ERROR "ap_docker_registry ${ap_docker_registry_pull} must end with '/'")
  endif()
endif()

if(NOT "${ap_docker_registry_pull_repo}" STREQUAL "")
  if(NOT "${ap_docker_registry_pull_repo}" MATCHES ".*/")
    message_color(ERROR "ap_docker_registry_pull_repo ${ap_docker_registry_pull_repo} must end with '/'")
  endif()
endif()
  
if(NOT "${ap_linux_distro}" MATCHES ".*:.*")
  message_color(ERROR "ap_linux_distro ${ap_linux_distro} must be formatted like 'distro:version' (e.g. almalinux:9.5).")
endif()

if(NOT "${ap_container_list}" STREQUAL "")
  if(NOT IS_ABSOLUTE ${ap_container_list})
    message_color(
        FATAL_ERROR
        "ap_container_list must be an absolute path. \n\tThe current value is invalid: \n\t${ap_container_list}. \n\tProvide a valid path with -Dap_container_list"
    )
  else()
    if(IS_DIRECTORY ${ap_container_list})
      message_color(
          FATAL_ERROR
          "ap_container_list must be a file. \n\tThe current value is invalid: \n\t${ap_container_list}."
      )
    else()
      if(NOT EXISTS ${ap_container_list})
        message_color(
            FATAL_ERROR
            "ap_container_list does no exist. \n\tThe current value is invalid: \n\t${ap_container_list}. \n\tProvide a valid path with -Dap_container_list"
        )
      endif()
    endif()
  endif()
  # A list (sep is semi-colon is needed here to be further expanded in the add_custom_command)
  # The option below will be pass to nextflow
  set(ap_container_list "--containerList;${ap_container_list}")
endif()

### Chech whether we have to use a docker registry or a podman registry
### to build the singularity images from a registry
if (ap_install_podman_recipes)
	set(docker_cmd_nfx "--dockerCmd;podman")
endif()
if (ap_install_docker_recipes)
	set(docker_cmd_nfx "--dockerCmd;docker")
endif()

### Allow the usage of the stub-run mode with nextflow
if(test_stub_run)
	set(test_stub_run "-stub-run")
else()
	set(test_stub_run "")
endif()

### Set option to build singularity images
if(ap_install_singularity_images AND NOT ap_install_singularity_images_from_registry)
	set(install_singularity_images_nfx "--buildSingularityImages;true;--buildSingularityRecipes;true")
endif()

if(ap_install_singularity_images_from_registry AND NOT ap_install_singularity_images)
	set(install_singularity_images_nfx "--buildSingularityImagesFromRegistry;true;--buildSingularityRecipes;true;--buildDockerRecipes;true;${docker_cmd_nfx}")
endif()
