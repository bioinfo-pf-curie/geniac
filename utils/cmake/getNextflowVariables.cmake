file(STRINGS "${nextflow_config_file}" nextflow_config)
file(WRITE ${nextflow_variables_file})
foreach(nextflow_config_line ${nextflow_config})

    if(${nextflow_config_line} MATCHES "publishDirSingularityImages")
        string(REGEX REPLACE ".*['\"](.*)['\"]" "\\1" nextflow_config_line "${nextflow_config_line}")
        file(APPEND ${nextflow_variables_file} "set(singularity_images_dir \"${nextflow_config_line}\")\n")
        set(ENV{singularity_images_dir} "${nextflow_config_line}")
    endif()

    if(${nextflow_config_line} MATCHES "publishDirDeffiles")
        string(REGEX REPLACE ".*['\"](.*)['\"]" "\\1" nextflow_config_line "${nextflow_config_line}")
        file(APPEND ${nextflow_variables_file} "set(deffiles_dir \"${nextflow_config_line}\")\n")
        set(ENV{deffiles_dir} "${nextflow_config_line}")
    endif()

    if(${nextflow_config_line} MATCHES "publishDirOutputConfig")
        string(REGEX REPLACE ".*['\"](.*)['\"]" "\\1" nextflow_config_line "${nextflow_config_line}")
        file(APPEND ${nextflow_variables_file} "set(output_config_dir \"${nextflow_config_line}\")\n")
        set(ENV{output_config_dir} "${nextflow_config_line}")
    endif()

endforeach()

message("outputDir is: K${output_config_dir}K")
message("imagedir is: K${deffiles_dir}K")
message("defdir is: K${singularity_images_dir}K")
