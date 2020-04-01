
# Create path directories


file(STRINGS "${path_link_file}" path_link)

foreach(path ${path_link})
    file(MAKE_DIRECTORY "${path_link_dir}/${path}")
endforeach()


