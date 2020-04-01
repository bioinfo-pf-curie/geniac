.. _admin-page:

*******************
Admin
*******************


Structure of the build directory tree
=====================================




Generate preload cache with default values
==========================================

In order to generate the pre-load a script ``utils/install/cmake-init-default.cmake`` to populate the *cmake* cache, use the ``utils/cmake/initCmakePreload.sh`` as follows:

::

   git_repo_url=http://myGitRepoUrl
   git_repo_name="myGitRepoName"
   git clone ${git_repo_url}
   mkdir build
   cd build
   ../${git_repo_name}/utils/cmake/initCmakePreload.sh ../${git_repo_name} > ../${git_repo_name}/utils/install/cmake-init-default.cmake

Containers
==========

Build
-----

The ``utils/install/singularity.nf`` and ``utils/install/docker.nf`` *nextflow* scripts allow the automatic generation of recipes *def files* and *Dockerfiles* respectively. They also allow the building of the containers.


Options can be passed to these scripts and can be seen the ``utils/install/nextflow.config``. 


These scripts are automatically called during the build step of the project (see :ref:`install-page`), thus you don't have to run them manually.

Labels
------

In order to tack from which repository and version the containers were built, some labels are added in the recipes. Here is an example from a singularity def file:

::

   %labels
       gitUrl ssh://git@gitlab.curie.fr:2222/pipeline_templates/data-analysis_template.git
       gitCommit 80f6511b453a365be39e3bede6d79f0ce7253d16
   

