# ##############################################################################
# Set CACHE variables
# ##############################################################################

set(ap_nf_executor
    "pbs"
    CACHE STRING "executor used by nextflow (e.g. pbs, slurm, etc.)")

# ap_annotation_path must STRING (and not PATH)
# this is the path where the annotations are available
set(ap_annotation_path
    ""
    CACHE
        STRING
        "Path to the annotations. A symlink annotations with the given target will be created."
)

# ap_singularity_image_path must STRING (and not PATH)
# this is the path where the singularity containers are available
set(ap_singularity_image_path
    ""
    CACHE
        STRING
        "Path to the singularity images. If the variable ap_use_singularity_image_link is ON, a symlink containers/singularity with the given target will be created."
)

set(ap_install_singularity_recipes
    "OFF"
    CACHE BOOL "Generate and install singularity def files")

set(ap_install_singularity_images
    "OFF"
    CACHE BOOL "Generate and install Singularity def files and images")

set(ap_install_docker_recipes
    "OFF"
    CACHE BOOL "Generate and install Dockerfiles")

set(ap_install_docker_images
    "OFF"
    CACHE BOOL "Generate and install Dockerfiles and images")

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

