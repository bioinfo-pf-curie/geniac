#!/bin/bash

function usage {
    echo -e "\nUsage: $(basename "$1") [Options]"
    echo -e "\n [Options]"
    echo -e "\t-g : git repository url" 
    echo -e "\t-t : git tag to deploy (can be a tag or commit id)"
    echo -e "\n\n [Example]: \n\t# ./deploy.sh -t 9d12c561 -g ssh://git@gitlab.curie.fr:2222/data-analysis/RNA-seq.git"
}

while getopts g:t:h: option; do
    case "${option}" in
        g)
            giturl=${OPTARG}
            ;;
        t)
            tag=${OPTARG}
            ;;
        \?)
            usage "$0" ; exit 1
            ;;
    esac
done
shift $((OPTIND-1))


workdir="${HOME}/install_analysis_pipeline_$(date +"%Y-%m-%d_%Hh%mmin%S.%3Nsec")_$RANDOM"
mkdir -p ${workdir}
mkdir -p ${workdir}/git
mkdir -p ${workdir}/build


echo "Working directory for installation process is ${workdir}"
cd ${workdir}/git

echo '### git init started ###'
git init -q 

echo '### git remote started ###'
git remote add origin ${giturl}

echo '### git fetch started ###'
git fetch

echo '### git checkout started ###'
git checkout -q -f ${tag}

echo '### git submodule started ###'
git submodule -q update --init --recursive

echo '### git clean started ###'
git clean -q -d -x -f
rm -Rf .git && rm -f .gitmodules

echo ${tag} > version


#### configure the project

echo '### cmake3 started ###'

cd ${workdir}/build

cmake3 ../git -C ../git/install/cmake-init.cmake

#make; make install
