.. _install-page:

*********************
Installation
*********************


We describe here how the analysis pipeline can be installed. We assume that the pipeline is available from the git repository ``myGitRepo``  at the url ``http://myGitRepoUrl`` and follows the expected organisation (ADD A LINK HERE).

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

.. _install-options:

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

   To have all the available options and help, run ``cmake -LAH ../${myGitRepo}`` in the ``build`` directory. The different options are displayed in the **Cache values** section:

Set options with a file
-----------------------


The file ``utils/install/cmake-init-default.cmake`` provides a script to set all the available variables during the configuration step. We recommand that you copy this file into ``utils/install/cmake-init.cmake``, edit it and set the different variables to match your configuration. Then you can configure the project as follows:

::

   cd build
   cmake -C ../${myGitRepo}/utils/install/cmake-init.cmake ../${myGitRepo}


.. note::
   On CentOS, the syntax in ``cmake3 ../${myGitRepo} -C ../${myGitRepo}/utils/install/cmake-init.cmake``




Containers
==========

In order to build singularity images, root credentials are required
* either type `make` if you have `fakeroot` singularity credentials
* or `sudo make` if you have sudo privileges
* then `make install`

If you want to build the recipes without installing them type  `make build_singularity_recipes`. Recipes will be generated in ``build/workDir/results/singularity/deffiles``.

If you want to build the images without installing them type `make build_singularity_images`. Images will be generated in ``build/workDir/results/singularity/images``.


Examples
========


Install and run with conda
--------------------------

Prerequisites:

You must have `conda <https://docs.conda.io/>`_ installed locally, if not, proceed as follows:

You must have git lfs.


-> en fait, cmake ne va modifier que les variables que tu lui demandes. Comme tu a utilisé en premier
'-Dap_install_singularity_images=ON", et que ensuite tu ne lui passe que 

"-DCMAKE_INSTALL_PREFIX=/data/tmp/nservant/myPipeline", il ne modifie pas -Dap_install_singularity_images.

Il faudrait lui dire "-Dap_install_singularity_images=ON". Bon, ce sont des petites subtilités qu'il faut que je documente.



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

   If you use both the conda and cluster profile, check that your master job that launches nextflow has been submitted with enough memory, otherwise the creation of the conda environment may fail.

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
   
