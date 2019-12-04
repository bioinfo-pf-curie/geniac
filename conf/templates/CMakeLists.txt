

set(ap_nf_executor "pbs" CACHE STRING "executor used by nextflow (e.g. pbs, slurm, etc.)")
set(ap_annotation_path "/to/replace" CACHE PATH "directory for the annotations used by the pipeline")
set(ap_singularity_image_path "/to/replace" CACHE PATH "directory for the singularity images used by the pipeline (when profile containers is used)")
set(ap_tools_path "/to/replace if ap_use_toolspath is ON" CACHE PATH "directory for the tools used by the pipeline (when profile toolsPath is used)")



if(${ap_use_containers})
    if(IS_DIRECTORY ${ap_singularity_image_path})
        message_color(OK "ap_singularity_image_path ${ap_singularity_image_path} exists")
   else()
        message_color(WARNING "ap_singularity_image_path ${ap_singularity_image_path} does not exist")
    endif()
endif()

if(${ap_use_toolspath})
    if(IS_DIRECTORY ${ap_tools_path})
        message_color(OK "ap_tools_path ${ap_tools_path} exists")
   else()
        message_color(WARNING "ap_tools_path ${ap_tools_path} does not exist")
    endif()
endif()

 
if(IS_DIRECTORY ${ap_annotation_path})
    message_color(OK "ap_annotation_path ${ap_annotation_path} exists")
else()
    message_color(WARNING "ap_annotation_path ${ap_annotation_path} does not exist")
endif()

file (GLOB ap_conf_template_file_list "${CMAKE_CURRENT_SOURCE_DIR}/*.in")

foreach(file ${ap_conf_template_file_list})
  get_filename_component(file ${file} NAME)
  string(REGEX REPLACE ".in$" "" file_output ${file})
  message_color(INFO "configure: ${file} into ${file_output}")

  configure_file(${file} ${CMAKE_BINARY_DIR}/nextflow_conf/${file_output} @ONLY)
  install(FILES ${CMAKE_BINARY_DIR}/nextflow_conf/${file_output} DESTINATION ${CMAKE_INSTALL_PREFIX}/conf)

endforeach(file ${ap_conf_template_file_list})



