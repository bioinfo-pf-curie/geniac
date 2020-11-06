#! /bin/bash

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


## this script allows to generate preload cmake cache

git_repo_dir=$1

 cmake  -LAH  "${git_repo_dir}" 2> /dev/null |  awk '{if(f)print} /-- Cache values/{f=1}' | grep -B 1 -E '^ap_|^ap_|^CMAKE_INSTALL_PREFIX:' | grep -v "\-\-" | sed 'N;s/\n/\/\//' | sed 's/\/\/ //' | sed -r 's|(.*)\/\/([A-Za-z_0-9]+):([A-Z]+)=(.*)|set(\2 "\4" CACHE \3 "\1")|'

