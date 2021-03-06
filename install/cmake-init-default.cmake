set(CMAKE_INSTALL_PREFIX "${HOME}" CACHE PATH "Install path prefix, prepended onto install directories.")
set(ap_annotation_path "" CACHE STRING "Path to the annotations. A symlink annotations with the given target will be created.")
set(ap_check_config_file_from_source "ON" CACHE BOOL "Check if the nextflow config files generated by geniac are present in the source directory. If this is the case, they are compared with those automatically generated by geniac during the build process. If one is different an ERROR is thrown.")
set(ap_install_docker_images "OFF" CACHE BOOL "Generate and install Dockerfiles and images")
set(ap_install_docker_recipes "OFF" CACHE BOOL "Generate and install Dockerfiles")
set(ap_install_singularity_images "OFF" CACHE BOOL "Generate and install Singularity def files and images")
set(ap_install_singularity_recipes "OFF" CACHE BOOL "Generate and install singularity def files")
set(ap_keep_envyml_from_source "OFF" CACHE BOOL "If present, the file environment.yml will be installed instead of the file automatically generated by geniac")
set(ap_nf_executor "pbs" CACHE STRING "executor used by nextflow (e.g. pbs, slurm, etc.)")
set(ap_singularity_image_path "" CACHE STRING "Path to the singularity images. If the variable ap_use_singularity_image_link is ON, a symlink containers/singularity with the given target will be created.")
