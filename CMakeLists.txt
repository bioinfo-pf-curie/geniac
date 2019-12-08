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

install(
        DIRECTORY ${CMAKE_SOURCE_DIR}/
        DESTINATION ${CMAKE_INSTALL_PREFIX}
        USE_SOURCE_PERMISSIONS
        PATTERN "conf/templates" EXCLUDE
        PATTERN ".git*" EXCLUDE
        PATTERN "CMakeLists.txt" EXCLUDE
        PATTERN "*.example" EXCLUDE
        PATTERN "utils/" EXCLUDE)

include("utils/cmake/utils.cmake")
add_subdirectory(utils)
add_subdirectory(conf/templates)

if (EXISTS ${CMAKE_SOURCE_DIR}/modules/CMakeLists.txt)
	add_subdirectory(modules)
endif()

