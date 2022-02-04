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

#########################################
# Create the geniac conda environment ###
#########################################

export GENIAC_CONDA="https://raw.githubusercontent.com/bioinfo-pf-curie/geniac/release/environment.yml"
wget ${GENIAC_CONDA}
conda create env -f environment.yml
conda activate geniac

####################################################
# Prepare the working directory for the use case ###
####################################################

export WORK_DIR="${HOME}/tmp/myPipeline"
export SRC_DIR="${WORK_DIR}/src"
export INSTALL_DIR="${WORK_DIR}/install"
export BUILD_DIR="${WORK_DIR}/build"
export GIT_URL="https://github.com/bioinfo-pf-curie/geniac-demo.git"

mkdir -p ${INSTALL_DIR} ${BUILD_DIR}

# clone the repository
# the option --recursive is needed if you use geniac as a submodule
git clone --recursive ${GIT_URL} ${SRC_DIR}

######################################
# Use case: add a Nextflow process ###
######################################

### edit the following file to add a new tool in the section params.geniac.tools
cat ${SRC_DIR}/conf/geniac.config

### edit the following file to add a new process with the new tool
cat ${SRC_DIR}/main.nf

##############################################
# Use case: check the code with the linter ###
##############################################

### check the code
geniac lint ${SRC_DIR}

################################################
# Use case: build the singularity containers ###
################################################

cd ${BUILD_DIR}

### configure the pipeline
cmake ${SRC_DIR}/geniac  -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} -Dap_install_singularity_images=ON -Dap_nf_executor=slurm


### /!\ with sudo, the singularity and nextflow commands must be
### /!\ in the secure_path option declared in the file /etc/sudoers

### build the files needed by the pipeline
sudo make

### change file owner/group to the current user
sudo chown -R $(id -gn):$(id -gn) ${BUILD_DIR}


###################################
# Use case: deploy the pipeline ###
###################################

### install the pipeline
make install


################################
# Use case: run the pipeline ###
################################

cd ${INSTALL_DIR}/pipeline

### locally on the computer
nextflow -c conf/test.config run main.nf -profile singularity

### on a computing cluster with slurm
nextflow -c conf/test.config run main.nf -profile singularity,cluster


#####################################
### Geniac command line interface ###
#####################################

export WORK_DIR="${HOME}/tmp/myPipeline_CLI"
export INSTALL_DIR="${WORK_DIR}/install"

geniac init -w ${WORK_DIR} ${GIT_URL}
cd ${WORK_DIR}
geniac lint
geniac install . ${INSTALL_DIR} -m singularity
sudo chown -R  $(id -gn):$(id -gn) build
geniac test singularity
geniac test singularity --check-cluster
