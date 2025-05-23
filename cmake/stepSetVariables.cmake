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
# Set CACHE variables
# ##############################################################################

set(ap_nf_executor
    "pbs"
    CACHE STRING "executor used by nextflow (e.g. pbs, slurm, etc.). Default is pbs")

# ap_annotation_path must STRING (and not PATH)
# this is the path where the annotations are available
set(ap_annotation_path
    ""
    CACHE
        STRING
        "Path to the annotations. A symlink annotations with the given target will be created. Default is empty."
)

# ap_singularity_image_path must STRING (and not PATH)
# this is the path where the singularity containers are available
set(ap_singularity_image_path
    ""
    CACHE
        STRING
        "Path to the singularity images. A symlink containers/singularity with the given target will be created. Default is empty."
)

set(ap_install_singularity_recipes
    "OFF"
    CACHE BOOL "Generate and install singularity def files. Default is OFF.")

set(ap_install_singularity_images
    "OFF"
    CACHE BOOL "Generate and install Singularity def files and images. Default is OFF.")

set(ap_install_docker_recipes
    "OFF"
    CACHE BOOL "Generate and install Dockerfiles. Default is OFF.")

set(ap_install_docker_images
    "OFF"
    CACHE BOOL "Generate and install Dockerfiles and docker images. Default is OFF.")

set(ap_install_podman_recipes
    "OFF"
    CACHE BOOL "Generate and install Dockerfiles. Default is OFF.")

set(ap_install_podman_images
    "OFF"
    CACHE BOOL "Generate and install Dockerfiles and podman images. Default is OFF.")

set(ap_keep_envyml_from_source
    "OFF"
    CACHE BOOL "If present, the file environment.yml will be installed instead of the file automatically generated by geniac. Default is OFF.")

set(ap_check_config_file_from_source
  "ON"
  CACHE BOOL "Check if the nextflow config files generated by geniac are present in the source directory. If this is the case, they are compared with those automatically generated by geniac during the build process. If one is different an ERROR is thrown. Default is ON.")

set(ap_docker_registry
    "4geniac/"
    CACHE
        STRING
  "Docker registry used to build the containers from recipes automatically generated by geniac. Default is 4geniac/ (see https://hub.docker.com/u/4geniac and https://github.com/bioinfo-pf-curie/4geniac)."
)

set(ap_linux_distro
    "almalinux:9.5"
    CACHE
        STRING
        "When building the docker/singularity images, geniac bootstraps from docker containers available on the docker hub registry https://hub.docker.com/u/4geniac. This variable defines which Linux distro (i.e. which repository) and which version (i.e. which tag) to use from https://hub.docker.com/u/4geniac. For details, about the docker containers see https://github.com/bioinfo-pf-curie/4geniac. Default is almalinux:9.5."
)

set(ap_conda_release
    "24.11.3-2"
    CACHE
        STRING
        "When building the docker/singularity images, geniac bootstraps from docker containers available on the docker hub registry https://hub.docker.com/u/4geniac. When a tool is installed with Conda, the container obviously needs Conda. Therefore, this variable defines which Conda release to use from https://hub.docker.com/u/4geniac. For details, about the docker containers see https://github.com/bioinfo-pf-curie/4geniac. Default is 24.11.3-2."
)

set(ap_container_list
    ""
    CACHE
        STRING
				"Provide PATH to a text file which contains the list of tool labels for which the containers will be built. This makes it possible to build only a subset of containers instead of building all the containers for all the tools."
)

set(ap_mount_dir
    ""
    CACHE
        STRING
        "Option is deprecated."
)

set(ap_singularity_build_options
    ""
    CACHE
        STRING
        "Allow to pass specific options when building singularity images. (e.g. --fakeroot). Default is empty."
)

# ##############################################################################
# Set variables
# ##############################################################################

# Directory names where nextflow will write its results
# TODO: is there a way to use parameters in geniac/nextflow.config ?
set(publish_dir_singularity_images "results/singularity/images")
set(publish_dir_conf "results/conf")
set(publish_dir_conda "results/conda")
set(publish_dir_deffiles "results/singularity/deffiles")
set(publish_dir_dockerfiles "results/docker/Dockerfiles")

# Set variable to define name of subdirectories where will be installed the
# pipeline and its dependencies such as singularity images. These variables are
# used in cmake/CMakeLists.txt
set(pipeline_dir "pipeline")
set(singularity_image_dir "containers/singularity")

# as the main CMakeLists.txt is in the geniac folder, the source of the pipeline
# is in the upper folder that is step in the pipeline_source_dir variable
set(pipeline_source_dir ${CMAKE_SOURCE_DIR}/..)
