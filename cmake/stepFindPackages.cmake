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
# Find packages
# ##############################################################################

set(CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake;${CMAKE_MODULE_PATH}")

find_package(Git 2.0)
find_package(Nextflow 20.01)
find_package(Singularity 3.2)
find_package(Docker 18.0)

if(GIT_FOUND)
    message_color(OK "Git found")
else()
    message_color(WARNING "Git not found")
endif()

if(NEXTFLOW_FOUND)
    message_color(OK "Nextflow found")
else()
    message_color(FATAL_ERROR
                  "Nextflow not found. It is required during the build step.")
endif()

if(SINGULARITY_FOUND)
    message_color(OK "Singularity found")
else()
    message_color(WARNING "Singularity not found")
endif()

if(DOCKER_FOUND)
    message_color(OK "Docker found")
else()
    message_color(WARNING "Docker not found")
endif()

