.. include:: substitutions.rst

.. _faq-page:

***
FAQ
***

How can I write the config files for the different nextflow profiles?
=====================================================================

The utilies we propose allow the automatic generation of all the config files for the nextflow :ref:`run-profiles`. However, if you really want to write them yourself follow the examples described in :ref:`profiles-page`.


How can i use nf-geniac on an existing repository?
==================================================

The structure of the repository is based on |nfcore|_ and additional files and folders are expected.

All the resources for nf-geniac are available here:

* |geniacrepo|_
* |geniacdemo|_
* |geniactemplate|_

Follow the guidelines below if you want to use nf-geniac on an existing repository. 

Create a the folder *geniac*
----------------------------

The guidelines and additional utilities we developed are in ``nf-geniac`` should be located in a folder named ``geniac`` in your new repository. The utilities in the ``geniac`` folder can either be copied or link to your pipeline repository as a
|gitsubmodule|_.

.. note::

    If the ``geniac`` is used as a submodule in your repository, execute  the command ``git submodule update --init --recursive`` once you have created the ``geniac`` submodule, otherwise the ``geniac`` folder will remain empty.
    
    If you want to create a submodule, you can edit and modify the variables in the file :download:`createSubmodule.bash <../data/createSubmodule.bash>` and follow the procedure.


Create additional files and folders
-----------------------------------

The following files are mandatory:

* :download:`CMakeLists.txt <../data/CMakeLists.txt>`: as the :ref:`install-page` requires ``cmake``, you need to copy this file in your repository. Check that the file is named ``CMakeLists.txt``.
* :download:`cluster.config.in <../data/conf/templates/cluster.config.in>`: copy the file in the folder ``conf/templates``. This file is used by ``cmake`` to set which job scheduler is used in the ``cluster.config`` profile.
* :download:`CMakeLists.txt <../data/modules/CMakeLists.txt>`: create a folder named ``modules`` and copy this file inside if your need to :ref:`process-source-code`. Check that the file is named ``CMakeLists.txt``.
* :download:`base.config <../data/conf/base.config>`: copy the file in the folder ``conf``. This file containes a scope names ``geniac`` that defines all the nextflow variables needed to build, deploy and run the pipeline.

Moreover, depending on which case your are when you :ref:`process-page`, you can create whenever youd need them the following folders:

::

   ├── env
   ├── modules
   ├── recipes
   │   ├── conda
   │   ├── dependencies
   │   ├── docker
   │   └── singularity



How does the repository look like?
==================================

The source code of your repository should look like this:

::

   ├── assets                       # assets needed for runtime
   ├── bin                          # scripts or binaries for the pipeline
   ├── CMakeLists.txt
   ├── conf                         # configuration files for the pipeline
   │   ├── base.config              # contains the geniac scope mandatory for nextflow
   │   ├── templates                # template for nf-geniac
   │   │   └── cluster.config.in
   ├── docs                         # documentation of the pipeline
   ├── env                          # process specific environment variables
   ├── geniac                       # nf-geniac utilities
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
       ├── data
