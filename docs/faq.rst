.. include:: substitutions.rst

.. _faq-page:

***
FAQ
***

.. contents::
   :depth: 1
   :local:



How can I use geniac on an existing repository?
==================================================

The structure of the repository is based on |nfcore|_ and additional files and folders are expected.

All the resources for geniac are available here:

* |geniacdoc|_
* |geniacrepo|_
* |geniacdemo|_
* |geniacdemodsl2|_
* |geniactemplate|_
* Example: :download:`useCases.bash <../data/useCases.bash>`

Follow the guidelines below if you want to use geniac on an existing repository. 

Create a the folder *geniac*
----------------------------

The guidelines and additional utilities we developed are in ``geniac`` should be located in a folder named ``geniac`` in your new repository. The utilities in the ``geniac`` folder can either be copied or link to your pipeline repository as a
|gitsubmodule|_.

.. note::

    If the ``geniac`` is used as a submodule in your repository, execute  the command ``git submodule update --init --recursive`` once you have created the ``geniac`` submodule, otherwise the ``geniac`` folder will remain empty.
    
    If you want to create a submodule, you can edit and modify the variables in the file :download:`createSubmodule.bash <../data/createSubmodule.bash>` and follow the procedure.


Create additional files and folders
-----------------------------------

The following files are mandatory:

* :download:`CMakeLists.txt <../data/modules/CMakeLists.txt>`: create a folder named ``modules`` and copy this file inside if your need to :ref:`process-source-code`. Check that the file is named ``CMakeLists.txt``.
* :download:`geniac.config <../data/conf/geniac.config>`: copy the file in the folder ``conf``. This file contains a scope names ``geniac`` that defines all the nextflow variables needed to build, deploy and run the pipeline.

Moreover, depending on which case your are when you :ref:`process-page`, you can create whenever you need them the following folders:

::

   ├── env
   ├── modules
   └── recipes
       ├── conda
       ├── dependencies
       ├── docker
       └── singularity



How does the repository look like?
==================================

The source code of your repository should look like this:

::

   ├── assets                       # assets needed for runtime
   ├── bin                          # scripts or binaries for the pipeline
   ├── conf                         # configuration files for the pipeline
   │   ├── geniac.config            # contains the geniac scope mandatory for nextflow
   ├── docs                         # documentation of the pipeline
   ├── env                          # process specific environment variables
   ├── geniac                       # geniac utilities
   │   ├── cmake                    # source files for the configuration step
   │   ├── docs                     # guidelines for installation
   │   ├── install                  # scripts for the build step
   ├── main.nf
   ├── modules                      # tools installed from source code
   │   ├── CMakeLists.txt
   │   ├── helloWorld
   ├── nextflow.config
   ├── recipes                      # installation recipes for the tools
   │   ├── conda
   │   ├── dependencies
   │   ├── docker
   │   └── singularity
   └── test                         # data to test the pipeline
       └── data

How can I write the config files for the different nextflow profiles?
=====================================================================

The utilities we propose allow the automatic generation of all the config files for the nextflow :ref:`run-profiles`. However, if you really want to write them yourself follow the examples described in :ref:`profiles-page`.

How should I define the path to the genome annotations?
=======================================================

When the pipeline is installed with `geniac`, the :ref:`install-structure-dir-tree` contains a directory named ``annotations``. This directory can be a symlink to the directory with your existing annotations (can be set during :ref:`install-configure` with the option ``ap_annotation_path``). Check that:



1. The file :download:`geniac.config <../data/conf/geniac.config>` defines the ``genomeAnnotationPath`` in the scope ``params``  as follows:


::

   params {
   
     genomeAnnotationPath = params.genomeAnnotationPath ?: "${baseDir}/../annotations"
   
   }    

2. All the paths to your annotations are defined using the variable ``params.genomeAnnotationPath`` as shown in the file :download:`genomes.config <../data/conf/genomes.config>`

3. You use the variables defined in the :download:`genomes.config <../data/conf/genomes.config>` in the ``main.nf``, for example ``params.genomes['mm10'].fasta``

How can I pass specific options to run docker or singularity containers?
========================================================================

If needed, you can set the ``singularityRunOptions`` and ``dockerRunOptions`` values to whatever is needed for your configuration in the  ``geniac.config`` file. This will set the ``runOption`` parameters (see `Nextflow configuration <https://www.nextflow.io/docs/latest/config.html>`_) of the |singularity|_ and |docker|_ directive respectively to the selected value when the |singularity|_ and |docker|_ profiles will be called.

How can I see the recipes for the containers?
=============================================

As geniac automatically generates the recipes of the containers, they are not available in the git repository. However, they can be easily retrieved in several ways. An example to :ref:`install-generate-recipes` is provided.

Is geniac compatible with nextflow DSL2?
========================================


Since version 20.07.1, |nextflow|_ provides the `DSL2 <https://www.nextflow.io/docs/latest/dsl2.html>`_ syntax that allows the definition of module libraries and simplifies the writing of complex data analysis pipelines. geniac is fully compatible with `DSL2 <https://www.nextflow.io/docs/latest/dsl2.html>`_ and we provide |geniacdemodsl2|_ as an example. The guidelines to :ref:`process-page` remain exactly the same.


The main difference between  |geniacdemo|_  and  |geniacdemodsl2|_ are:

* each process is located in one dedicated file in the folder ``nf-modules/local/process``
* each subworkflow that combines different processes is located in the folder ``nf-modules/local/subworkflow``
* the ``main.nf`` includes these two folders and uses the ``workflow`` directive


::
   
   ├── assets                       # assets needed for runtime
   ├── bin                          # scripts or binaries for the pipeline
   ├── conf                         # configuration files for the pipeline
   │   ├── geniac.config            # contains the geniac scope mandatory for nextflow
   ├── docs                         # documentation of the pipeline
   ├── env                          # process specific environment variables
   ├── geniac                       # geniac utilities
   │   ├── cmake                    # source files for the configuration step
   │   ├── docs                     # guidelines for installation
   │   ├── install                  # scripts for the build step
   ├── main.nf
   ├── modules                      # tools installed from source code
   │   ├── CMakeLists.txt
   │   ├── helloWorld
   ├── nextflow.config
   ├── nf-modules                   # nextflow files for DSL2
   │   └── local
   │       ├── process
   │       │   ├── alpine.nf
   │       │   ├── checkDesign.nf
   │       │   ├── execBinScript.nf
   │       │   ├── fastqc.nf
   │       │   ├── getSoftwareVersions.nf
   │       │   ├── helloWorld.nf
   │       │   ├── multiqc.nf
   │       │   ├── outputDocumentation.nf
   │       │   ├── standardUnixCommand.nf
   │       │   ├── trickySoftware.nf
   │       │   └── workflowSummaryMqc.nf
   │       └── subworkflow
   │           ├── myWorkflow0.nf
   │           └── myWorkflow1.nf
   ├── recipes                      # installation recipes for the tools
   │   ├── conda
   │   ├── dependencies
   │   ├── docker
   │   └── singularity
   └── test                         # data to test the pipeline
       └── data


The |geniacdemodsl2|_ can be run as follows:

::

   export WORK_DIR="${HOME}/tmp/myPipelineDSL2"
   export SRC_DIR="${WORK_DIR}/src"
   export INSTALL_DIR="${WORK_DIR}/install"
   export BUILD_DIR="${WORK_DIR}/build"
   export GIT_URL="https://github.com/bioinfo-pf-curie/geniac-demo-dsl2.git"
   
   mkdir -p ${INSTALL_DIR} ${BUILD_DIR}
   
   git clone --recursive ${GIT_URL} ${SRC_DIR}
   ### the option --recursive is needed if you use geniac as a submodule
   
   cd ${BUILD_DIR}
   cmake ${SRC_DIR}/geniac -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}
   make
   make install
   
   cd ${INSTALL_DIR}/pipeline
   
   nextflow -c conf/test.config run main.nf -profile multiconda

What are the @git_*@ variables?
===============================

You will find in both the ``main.nf`` and ``nextflow.config`` some variables surrounded by ``@`` such ``as @git_repo_name@``. These variables are used during the ``cmake`` step to extract the information from the git repository and replace them by their value. These variables are used in the nextflow manifest for example. If needed, you can remove these variables and set the value to whatever you want.

Why the conda profile fails to build its environment or takes to much time?
===========================================================================

The :ref:`run-profile-conda` relies on the ``environment.yml`` that is automatically generated by `geniac`. However, building a |conda| recipe can sometimes be very tricky as the order of the channels and the dependencies matters. `geniac` can not guess what is the appropriate order. Moreover, |conda| may want to solve conflicts between incompatible packages. Thus, in some cases, you will have no choice but to correct the ``environment.yml`` file manually, add it the git repository (where is located the ``main.nf`` file) and install the pipeline with the following options:

::

   cmake ${SRC_DIR}/geniac -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} -Dap_keep_envyml_from_source=ON

Note that it may be impossible to have a working ``environment.yml`` file due to the incompatibility between tools. Use the :ref:`run-profile-multiconda` profile instead of the :ref:`run-profile-conda` profile.

