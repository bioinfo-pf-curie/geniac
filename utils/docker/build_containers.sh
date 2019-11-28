#!/bin/bash
## build_containers.sh 
## Utiliti of RNA-seq pipeline
##
## Copyright (c) 2019-2020 Institut Curie
## Author(s): Nicolas Servant, Philippe La Rosa
## Contact: nicolas.servant@curie.fr, philippe.larosa@curie.fr
## This software is distributed without any guarantee under the terms of the BSD-3 licence.
## See the LICENCE file for details
##
##
## Run by root user or user with sudo
##
## usage : bash build_containers.sh 2>&1 | tee -a build_containers.log 
##

for IMGNAME in $(cat images_list.txt)
 do 
   echo "## build image ${IMGNAME}" 
   echo "sudo docker build ./${IMGNAME} -t ${IMGNAME}"
 done 

