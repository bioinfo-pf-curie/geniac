#! /bin/bash

## this script allows to generate preload cmake cache

git_repo_dir=$1

 cmake  -LAH  "${git_repo_dir}" 2> /dev/null |  awk '{if(f)print} /-- Cache values/{f=1}' | grep -B 1 -E '^ap_|^ap_|^CMAKE_INSTALL_PREFIX:' | grep -v "\-\-" | sed 'N;s/\n/\/\//' | sed 's/\/\/ //' | sed -r 's|(.*)\/\/([A-Za-z_0-9]+):([A-Z]+)=(.*)|set(\2 "\4" CACHE \3 "\1")|'

