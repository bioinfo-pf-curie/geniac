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

### install the geniac command line interface:
conda create -n geniac-cli python=3.9
conda activate geniac-cli
pip install git+https://github.com/bioinfo-pf-curie/geniac.git@release

### check the code
geniac lint ${SRC_DIR}


################################################
# Use case: build the singularity containers ###
################################################

cd ${BUILD_DIR}
cmake ${SRC_DIR}/geniac  -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} -Dap_install_singularity_images=ON
sudo "PATH=$PATH" make
sudo chown -R $(id -gn):$(id -gn) ${BUILD_DIR}


###################################
# Use case: deploy the pipeline ###
###################################

make install


################################
# Use case: run the pipeline ###
################################

cd ${INSTALL_DIR}/pipeline
nextflow -c conf/test.config run main.nf -profile singularity
