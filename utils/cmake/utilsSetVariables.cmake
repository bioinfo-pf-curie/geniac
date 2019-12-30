# ##############################################################################
# Set CACHE variables
# ##############################################################################

set(ap_nf_executor
    "pbs"
    CACHE STRING "executor used by nextflow (e.g. pbs, slurm, etc.)")

set(ap_use_annotation_link
    "OFF"
    CACHE
        BOOL
        "The directory annotations will be a symlink with the target given in the variable ap_annotation_path"
)
# ap_annotation_path must STRING (and not PATH)
set(ap_annotation_path
    "/to/be/replaced by your path"
    CACHE
        STRING
        "Path to the annotations. If the variable ap_use_annotation_link is ON, a symlink annotations with the given target will be created."
)

set(ap_use_singularity_image_link
    "OFF"
    CACHE
        BOOL
        "The directory containers/singularity will be a symlink with the target given in the variable ap_singularity_image_path"
)

# ap_singularity_image_path must STRING (and not PATH)
set(ap_singularity_image_path
    "/to/be/replaced by your path"
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
set(publish_dir_singularity_images "results/singularity/images")
set(publish_dir_conf "results/conf")
set(publish_dir_deffiles "results/singularity/deffiles")
set(publish_dir_dockerfiles "results/docker/Dockerfiles")

