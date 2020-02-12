.. _install-page:

*********************
Installation
*********************


We describe here how the analysis pipeline can be installed. We assume that the pipeline is available from the git repository ``myGitRepo``  at the url ``http://myGitRepoUrl`` and follows the expected organisation (see :ref:`overview-source-tree`).

Installation require cmake (version 3.0 or above) and consists of the following sequence.

::

   git_repo="myGitRepo"
   git_repo_url="http://myGitReporUrl"

   git clone ${git_repo_url}

   mkdir build
   cd build
   cmake ../${git_repo}     # configure the pipeline
   make                     # build the files needed by the pipeline
   make install             # install the pipeline

.. note::

   If you use CentOS cmake 3 is available as ``cmake3``. You can alias ``cmake3`` as ``cmake`` in your ``.bashrc`` if needed.

Different options can be passed to cmake for the configuration step. They are described in the following section.

.. _install-configure:

Configure
=========

List of options
---------------

The configure options for the **a**\nalysis **p**\ipeline start with the prefix **ap** and are in lower case. Options in upper case are cmake variables.

CMAKE_INSTALL_PREFIX
++++++++++++++++++++

This is the cmake variable to set the install directory.

ap_annotation_path
++++++++++++++++++

| STRING
| Path to the annotations. If the variable ``ap_use_annotation_link`` is ON, a symlink ``annotations`` with the given target will be created in the install directory.
| This is useful if the annotations are already available.


ap_install_docker_images
++++++++++++++++++++++++

| BOOL
| Generate and install Dockerfiles and images if set to ON.
| Default is OFF.

ap_install_docker_recipes
+++++++++++++++++++++++++

| BOOL
| Generate and install Dockerfiles if set to ON.
| Default is OFF.

ap_install_singularity_images
+++++++++++++++++++++++++++++

| BOOL
| Generate and install Singularity def files and images if set to ON.
| Default is OFF.

ap_install_singularity_recipes
++++++++++++++++++++++++++++++

| BOOL
| Generate and install singularity def files if set to ON.
| Default is OFF.

ap_nf_executor
++++++++++++++

| STRING
| executor used by nextflow (e.g. pbs, slurm, etc.).
| Default is pbs.

ap_singularity_image_path
+++++++++++++++++++++++++

| STRING
| Path to the singularity images. If the variable ``ap_use_singularity_image_link`` is ON, a symlink ``containers/singularity`` with the given target will be created in the install directory.
| This is useful if the singularity containers are already available.

ap_use_annotation_link
++++++++++++++++++++++

| BOOL
| The directory ``annotations`` will be a symlink with the target given in the variable ``ap_annotation_path``.
| Default is OFF.

ap_use_singularity_image_link
+++++++++++++++++++++++++++++

| BOOL
| The directory ``containers/singularity`` will be a symlink with the target given in the variable ``ap_singularity_image_path``.
| Default is OFF

.. warning::

   Options ``ap_install_singularity_images`` and ``ap_use_singularity_image_link`` are exclusive.

Set options in CLI
------------------

All the options can be set on the command line interface. If your want to install the pipeline in ``$HOME/myPipeline`` directory and build and install the singularity images, run:

::

   cd build
   cmake -C ../${myGitRepo}  -DCMAKE_INSTALL_PREFIX=$HOME/myPipeline -Dap_install_singularity_images=ON
   

.. tip::

   To have all the available options and help, run ``cmake -LAH ../${myGitRepo}`` in the ``build`` directory. The different options are displayed in the **Cache values** section.

.. _install-configure-file:

Set options with a file
-----------------------


The file ``utils/install/cmake-init-default.cmake`` provides a script to set all the available variables during the configuration step. We recommend that you copy this file into ``utils/install/cmake-init.cmake``, edit it and set the different variables to match your configuration. Then you can configure the project as follows:

::

   cd build
   cmake -C ../${myGitRepo}/utils/install/cmake-init.cmake ../${myGitRepo}


.. note::
   On CentOS, the syntax is ``cmake3 ../${myGitRepo} -C ../${myGitRepo}/utils/install/cmake-init.cmake``




Containers
==========

.. warning::

   In order to build singularity images, **root** credentials are required:
   
   * either type `make` if you have `fakeroot` singularity credentials
   * or `sudo make` if you have sudo privileges
   * then `make install`

In order to build the containers, you can either pass the required options during the configure stage (see :ref:`install-configure`) or use custom targets (see :ref:`install-target-containers`).

Custom targets
==============

.. _install-target-containers:

Build recipes and containers
----------------------------

Assume you are in the ``build`` directory. The following custom targets allows you to build recipes and containers even you did not ask for them during the configure stage:

* ``make build_singularity_recipes``
* ``make build_singularity_images``
* ``make build_docker_recipes``
* ``make build_docker_images``


For singularity:

* Recipes will be generated in ``build/workDir/results/singularity/deffiles``.
* Images will be generated in ``build/workDir/results/singularity/images``.

For docker:

* Recipes will be generated in ``build/workDir/results/docker/Dockerfiles``.
* Images will be created in the registry.


.. _install-test:

Install and test with different profiles
----------------------------------------

In order to make the deployment and testing of the pipeline easier, several custom targets are provided such that you only need to type one of the following command to install the pipeline:



* ``make test_conda``
* ``make test_docker``
* ``make test_multiconda``
* ``make test_path``
* ``make test_singularity``
* ``make test_standard``

Assuming that you configured the build directory such that ``CMAKE_INSTALL_PREFIX=$HOME/myPipeline``, typing ``make test_conda`` is similar to:

::

   make
   make install
   cd $HOME/myPipeline
   nextflow -c conf/test.config run main.nf -profile conda

If you want to add the :ref:`run-profile-cluster` profile, just type the following:

* ``make test_conda_cluster``
* ``make test_docker_cluster``
* ``make test_multiconda_cluster``
* ``make test_path_cluster``
* ``make test_singularity_cluster``
* ``make test_standard_cluster``


.. note::

   For these custom targets to be available, test data and ``conf/test.config`` file have to be provided in the repository.

Structure of the installation directory tree
============================================

::

   ├── annotations
   ├── containers
   │   └── singularity
   ├── path
   │   ├── alpine
   │   │   └── bin
   │   ├── fastqc
   │   │   └── bin
   │   ├── helloWorld
   │   │   └── bin
   │   ├── rmarkdown
   │   │   └── bin
   │   └── trickySoftware
   │       └── bin
   └── pipeline
       ├── assets
       ├── bin
       ├── conf
       ├── docs
       ├── env
       ├── modules
       │   └── helloWorld
       ├── recipes
       │   ├── conda
       │   ├── dependencies
       │   ├── docker
       │   └── singularity
       └── test
           └── data

Examples
========


Install and run with conda
--------------------------

.. important::

   You must have `conda <https://docs.conda.io/>`_ installed locally, if not, proceed as follows:


::

   wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
   bash Miniconda3-latest-Linux-x86_64.sh

   
Then, edit your file ``.bashrc`` and add ``$HOME/miniconda3/bin`` (or the install directory you set) in your PATH.


::

   git_repo="myGitRepo"
   git_repo_url="http://myGitReporUrl"

   git clone ${git_repo_url}

   mkdir build
   cd build
   cmake ../${myGitRepo}  -DCMAKE_INSTALL_PREFIX=$HOME/myPipeline
   make
   make install

   cd $HOME/myPipeline/pipeline

   nextflow -c conf/test.config run main.nf -profile conda
   

.. note::

   If you use both the :ref:`run-profile-conda`
   and :ref:`run-profile-cluster` profile, check that your master job that launches nextflow has been submitted with enough memory, otherwise the creation of the conda environment may fail.

Install and run with singularity
--------------------------------

::

   git_repo="myGitRepo"
   git_repo_url="http://myGitReporUrl"

   git clone ${git_repo_url}

   mkdir build
   cd build
   cmake ../${myGitRepo}  -DCMAKE_INSTALL_PREFIX=$HOME/myPipeline -Dap_install_singularity_images=ON
   make ### must be done with the root credentials
   make install

   cd $HOME/myPipeline/pipeline

   nextflow -c conf/test.config run main.nf -profile singularity


.. note::

   Whenever you explicitely set an option on the command line such as ``-Dap_install_singularity_images=ON``, and then you want to reconfigure your build directory by specifying only another option on the command line such as ``-DCMAKE_INSTALL_PREFIX=$HOME/myPipelineNewDir``, the ``ap_install_singularity_images`` will remain ``ON`` unless you specify ``-Dap_install_singularity_images=ON``.

