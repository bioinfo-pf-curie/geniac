cmake_minimum_required(VERSION 3.10.2)

project(analysis_pipeline LANGUAGES NONE)

set(CMAKE_BUILD_TYPE Release)

# force out-of-source build
if(${CMAKE_SOURCE_DIR} STREQUAL ${CMAKE_BINARY_DIR})
        message(
                FATAL_ERROR
                        "In-source builds not allowed.
		Please make a new directory (called a build directory) and run CMake from there.
		You may need to remove CMakeCache.txt.")
endif()


# name of subdirectories where will be installed
# the pipeline and its dependencies

set(pipeline_dir "pipeline")
set(singularity_image_dir "containers/singularity")

install(
        DIRECTORY ${CMAKE_SOURCE_DIR}/
        DESTINATION ${CMAKE_INSTALL_PREFIX}/${pipeline_dir}
        USE_SOURCE_PERMISSIONS
        PATTERN "conf/templates" EXCLUDE
        PATTERN ".git*" EXCLUDE
        PATTERN "CMakeLists.txt" EXCLUDE
        PATTERN "*.example" EXCLUDE
        PATTERN "utils" EXCLUDE)

    include("utils/cmake/utilsColorMessage.cmake")
add_subdirectory(utils)

if (EXISTS ${CMAKE_SOURCE_DIR}/modules/CMakeLists.txt)
	add_subdirectory(modules)
endif()

