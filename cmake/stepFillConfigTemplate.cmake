# ##############################################################################
# Fill template for config files
# ##############################################################################

file(GLOB ap_conf_template_file_list "${pipeline_source_dir}/conf/templates/*.in")

foreach(file ${ap_conf_template_file_list})
    get_filename_component(file ${file} NAME)
    string(REGEX REPLACE ".in$" "" file_output ${file})
    message_color(INFO "configure: ${file} into ${file_output}")

    configure_file(${pipeline_source_dir}/conf/templates/${file}
                   ${CMAKE_BINARY_DIR}/nextflowConf/${file_output} @ONLY)
    install(FILES ${CMAKE_BINARY_DIR}/nextflowConf/${file_output}
            DESTINATION ${CMAKE_INSTALL_PREFIX}/${pipeline_dir}/conf)

endforeach(file ${ap_conf_template_file_list})
