#! /bin/bash


### <<<< MODIFY BELOW WITH YOUR CONFIGURATION

### information about your repository
GIT_CONTAINER_BRANCH="devel"

### information about nf-geniac
GIT_SUBMODULE_REPO="https://github.com/bioinfo-pf-curie/"
GIT_SUBMODULE_DIR="geniac"
GIT_SUBMODULE_SHA1="f39ebdc4"
GIT_SUBMODULE_BRANCH="release"

GIT_COMMIT_MSG="[MODIF] add nf-geniac as a submodule using commit ${GIT_SUBMODULE_SHA1}"

### END: MODIFY BELOW WITH YOUR CONFIGURATION >>>

### prerequisites
git config --global status.submoduleSummary true
git config --global diff.submodule log


### Add the submodule in your git repository
git submodule add ${GIT_SUBMODULE_REPO} ${GIT_SUBMODULE_DIR}

### Activate the use of the submodule in the repository
git submodule update --init --recursive


##################################
### cd the submodule directory ###
##################################


cd ${GIT_SUBMODULE_DIR}

### check information about the submodule (which is a git repository inside the git repository)
git branch -vv 

### checkout the branch that contains the commit (or version) we want to use
git checkout ${GIT_SUBMODULE_BRANCH}

### download the git submodule repository
git fetch

### checkout the commit (or version) we want to use as a Detached HEAD
git checkout ${GIT_SUBMODULE_SHA1}


### check information about the submodule (we should be on a Detached HEAD with the expected commit)
git branch -vv 


#####################################################
### cd the root directory of your main repository ###
#####################################################

cd ..

git status
git branch -vv
git add ${GIT_SUBMODULE_DIR}
git commit -m "${GIT_COMMIT_MSG}"
git push origin ${GIT_CONTAINER_BRANCH}


