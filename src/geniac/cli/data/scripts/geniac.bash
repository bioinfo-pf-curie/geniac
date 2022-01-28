#!/bin/bash

set -oue pipefail

# TODO: should be internal/ run before any step requiring cmake3
### cmake3 on CentOS / or cmake in other Linux Distro
type cmake3 && export CMAKE_BIN="cmake3" || export CMAKE_BIN="cmake"

option=$1

# TODO: should be internal/ run before any build step
# CMD: geniac.bash init DIR URL
# - MKDIR GENIAC_TEMP_DIR
# - CLONE PROJECT IN GENIAC_TEMP_DIR/SRC
# - MKDIR GENIAC_TEMP_DIR/build
# - MKDIR GENIAC_TEMP_DIR/.geniac
function geniac_init {
  # - Create a new working directory for geniac with src, build and .geniac subfolders
  # - Clone the source code into the src folder
  # $1 is the name of the main folder
  # $2 is the the git url to the nextflow repository where geniac has been setup
  folder=$1
  url=$2
  echo "Init ${folder} as geniac working directory"
  mkdir -p ${folder}
  # Clone the repository inside src folder of the main working directory
  git clone --recurse-submodules ${url} ${folder}/src
  mkdir -p ${folder}/build
  mkdir -p ${folder}/.geniac
  ## cd the init folder
  cd ${folder}
  echo "Geniac init OK"
  $SHELL
}

# TODO: geniac install -h
# CMD:
# - GENIAC INIT
# - CD GENIAC_TEMP_DIR/build
# - RUN CMAKE GENIAC_TEMP_DIR/src/geniac > /dev/null
# - CLEAN GENIAC_TEMP_DIR/build IF CMAKE FAIL
# - RUN & CATCH CMAKE -LAH GENIAC_TEMP_DIR/src/geniac 2> /dev/null
# - FORMAT CMAKE OUTPUT
function geniac_options {
  if [[ ! -d .geniac ]]; then
    echo "ERROR: you are not in a folder created by geniac init"
    exit 1
  fi
  echo "Geniac options"
  cd build
  set +e
  ${CMAKE_BIN} ../src/geniac > /dev/null
  ### cmake may fails (eg: nextflow not in the PATH)
  ### in that case, the build dir has to be cleaned
  if [[ $? -ne 0 ]]; then
    set -e
    cd ${current_dir}
    rm -rf build
    mkdir -p build
    exit 1
  fi
  set -e
  ${CMAKE_BIN}  -LAH  ../src/geniac 2> /dev/null |  awk '{if(f)print} /-- Cache values/{f=1}' | grep -B 1 -E '^ap_|^ap_|^CMAKE_INSTALL_PREFIX:' | grep -v "\-\-" | sed 'N;s/\n/\/\//' | sed 's/\/\/ //' | sed -r 's|(.*)\/\/([A-Za-z_0-9]+):([A-Z]+)=(.*)|set(\2 "\4" CACHE \3 "\1")|' | sed -e 's|set(||g' | sed -e 's|)$||g'  | sed -e "s|CACHE.* \"|\"|g" | awk '{print "\n-D"$1, "\n\tcurrent value: "$2; $1=$2=""; print "\tdefinition:"$0}' | sed -e 's|:  "|: "|'

}

function geniac_test {
  # $1 is the nextflow profile
  # $2 are the args (cmake style with -D) to be passed to cmake (eg -Dap_install_singularity_images)
  nextflow_profile=$1
  if [[ ! -d .geniac ]]; then
    echo "ERROR: you are not in a folder created by geniac init"
    exit 1
  fi

  echo "Geniac test"
  current_dir=$(pwd)
  echo "TEST: the pipeline will be installed in ${current_dir}/test"
  cd build
  ### singularity
  if [[ ${nextflow_profile} == "singularity" ]]; then
    sudo ${CMAKE_BIN} ../src/geniac -Dap_install_singularity_images=ON -Dap_install_docker_images=OFF
    sudo chown -R $(id -gn):$(id -gn) ${current_dir}
  fi
  ### docker
  if [[ ${nextflow_profile} == "docker" ]]; then
    sudo ${CMAKE_BIN} ../src/geniac -Dap_install_docker_images=ON -Dap_install_singularity_images=OFF
    sudo chown -R $(id -gn):$(id -gn) ${current_dir}
  fi
  set +e
  ${CMAKE_BIN} ../src/geniac -DCMAKE_INSTALL_PREFIX=${current_dir}/test ${@:2}
  if [[ $? -ne 0 ]]; then
    set -e
    cd ${current_dir}
    rm -rf build
    mkdir -p build
    exit 1
  fi
  set -e
  make test_${nextflow_profile}
  cd ${current_dir}
}

function geniac_install {
  # $1 is the install folder
  # $2 are the args (cmake style with -D) to be passed to cmake (eg -Dap_install_singularity_images)
  if [[ ! -d .geniac ]]; then
    echo "ERROR: you are not in a folder created by geniac init"
    exit 1
  fi

  echo "Geniac install"
  current_dir=$(pwd)
  cd build
  set +e
  ${CMAKE_BIN} ../src/geniac -DCMAKE_INSTALL_PREFIX=$1 ${@:2}
  if [[ $? -ne 0 ]]; then
    set -e
    cd ${current_dir}
    rm -rf build
    mkdir -p build
    exit 1
  fi
  set -e
  make
  make install
  cd ${current_dir}
}

function geniac_recipes {
  # $1 is either {docker,singularity}
  container=$1
  if [[ ! -d .geniac ]]; then
    echo "ERROR: you are not in a folder created by geniac init"
    exit 1
  fi

  echo "Geniac recipes"
  current_dir=$(pwd)
  cd build
  ${CMAKE_BIN} ../src/geniac
  set +e
  make build_${container}_recipes
  if [[ $? -ne 0 ]]; then
    set -e
    cd ${current_dir}
    rm -rf build
    mkdir -p build
    exit 1
  fi
  set -e
  if [[ ${container} == "docker" ]]; then
    echo "The ${container} recipes are available in ${current_dir}/build/workDir/results/docker/Dockerfiles"
    ls workDir/results/docker/Dockerfiles/*.Dockerfile
  else
    echo "The ${container} recipes are available in ${current_dir}/build/workDir/results/singularity/deffiles"
    ls workDir/results/singularity/deffiles/*.def
  fi
  echo "Use 'geniac install' with your options to install the pipeline."
  cd ${current_dir}
}

function geniac_images {
  # $1 is either {docker,singularity}
  container=$1
  if [[ ! -d .geniac ]]; then
    echo "ERROR: you are not in a folder created by geniac init"
    exit 1
  fi

  echo "Geniac images"
  current_dir=$(pwd)
  cd build
  set +e
  ${CMAKE_BIN} ../src/geniac
  sudo make build_${container}_images
  if [[ $? -ne 0 ]]; then
    set -e
    cd ${current_dir}
    rm -rf build
    mkdir -p build
    exit 1
  fi
  set -e
  if [[ ${container} == "docker" ]]; then
    echo "The ${container} images have been pushed on the registry"
  else
    echo "The ${container} images are available in ${current_dir}/build/workDir/results/singularity/images"
    ls workDir/results/singularity/images/*.sif
  fi
  echo "Use 'geniac install' with your options to install the pipeline."
  sudo chown -R $(id -gn):$(id -gn) ${current_dir}
  cd ${current_dir}
}


function geniac_configfiles {
  # $1 is either {docker,singularity}
  if [[ ! -d .geniac ]]; then
    echo "ERROR: you are not in a folder created by geniac init"
    exit 1
  fi

  echo "Geniac configfiles"
  current_dir=$(pwd)
  cd build
  ${CMAKE_BIN} ../src/geniac
  set +e
  make build_config_files
  if [[ $? -ne 0 ]]; then
    set -e
    cd ${current_dir}
    rm -rf build
    mkdir -p build
    exit 1
  fi
  set -e
  echo "The config files automatically generated by geniac are available in ${current_dir}/build/workDir/conf"
  ls workDir/results/conf/*.config

  echo "Use 'geniac install' with your options to install the pipeline."
  cd ${current_dir}
}

# Remove the build folder
function geniac_clean {
  if [[ ! -d .geniac ]]; then
    echo "ERROR: you are not in a folder created by geniac init"
    exit 1
  fi

  echo "Geniac clean"
  rm -rf build/*
}


case "${option}" in
    clean)
        geniac_clean
        ;;
    configfiles)
        geniac_configfiles
        ;;
    images)
        geniac_images ${@:2}
        ;;
    init)
        geniac_init ${@:2}
        ;;
    install)
        geniac_install ${@:2}
        ;;
    install+docker)
        geniac_install ${@:2} -Dap_install_docker_images=ON -Dap_install_docker_images=OFF
        ;;
    install+singularity)
        geniac_install ${@:2} -Dap_install_singularity_images=ON -Dap_install_docker_images=OFF
        ;;
    options)
        geniac_options
        ;;
    recipes)
        geniac_recipes ${@:2}
        ;;
    test)
        geniac_test ${@:2}
        ;;
    help)
        echo "Write help"
        ;;
    *)
        echo "ERROR: unkwon option" ; exit 1
        ;;
esac
