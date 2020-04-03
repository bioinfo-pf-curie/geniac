.. _overview-page:

********
Overview
********

This section just provides a general overview of the guidelines for the structure of the source code directory and the naming conventions. The most important guidelines are detailed in the :ref:`process-page` section.

Prerequisites
=============

The following software are required:

* `nextflow <https://www.nextflow.io/>`_ >= 19.10.0
* `git <https://git-scm.com/>`_  >= 2.0
* `git lfs <https://git-lfs.github.com/>`_
* `cmake <https://cmake.org/>`_ >= 3.0

To use the containers, at least one of the following software is required:

* `singularity <https://sylabs.io/singularity/>`_ >= 3.2
* `docker <https://www.docker.com/>`_ >= 18.0

.. _overview-source-tree:


Start a new repository
======================


Structure of the source code directory tree
-------------------------------------------

The structure of the repository is based on `nf-core <https://nf-co.re/>`_ and additional files and folders are expected. Follow the guidelines below to initiate your repository. Initiate your repository using the `nf-core <https://nf-co.re/>`_  template.

Create a the folder *geniac*
++++++++++++++++++++++++++++


The guidelines and additional utilities we developed are in ``nf-geniac`` should be located in a folder named ``geniac`` in your new repository. The utilities in the ``geniac`` folder can either be copied or link to your pipeline repository as a
`git submodule <https://git-scm.com/book/en/v2/Git-Tools-Submodules>`_.

.. note::

    If the ``geniac`` is used as a submodule in your repository, execute  the command ``git submodule update --init --recursive`` once you have created the ``geniac`` submodule, otherwise the ``geniac`` folder will remain empty.
    
    If you want to create a submodule, you can edit and modify the variables in the file :download:`createSubmodule.bash <../data/createSubmodule.bash>` and follow the procedure.


Create additional files and folders
+++++++++++++++++++++++++++++++++++

The following files are mandatory:

* :download:`CMakeLists.txt <../data/CMakeLists.txt>`: as the :ref:`install-page` requires ``cmake``, you need to copy this file in your repository. Check that the file is named ``CMakeLists.txt``.
* :download:`cluster.config.in <../data/conf/templates/cluster.config.in>`: copy the file in the folder ``conf/templates``. This file is used by ``cmake`` to set which job scheduler is used in the ``cluster.config`` profile.
* :download:`CMakeLists.txt <../data/modules/CMakeLists.txt>`: create a folder named ``modules`` and copy this file inside if your need to :ref:`process-source-code`. Check that the file is named ``CMakeLists.txt``.

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
----------------------------------

The source code of your repository should look like this:

::

   ├── assets
   ├── bin
   ├── CMakeLists.txt
   ├── conf
   │   ├── templates
   │   │   └── cluster.config.in
   ├── docs
   ├── env
   ├── geniac
   │   ├── cmake
   │   ├── docs
   │   ├── install
   ├── main.nf
   ├── modules
   │   ├── CMakeLists.txt
   │   ├── helloWorld
   ├── nextflow.config
   ├── README.md
   ├── recipes
   │   ├── conda
   │   ├── dependencies
   │   ├── docker
   │   └── singularity
   └── test
       ├── data

.. _overview-naming:

Naming convention
=================

Variables
---------


Use camelCase, for example ``outputDir = './results'``.


Channels
--------


Use camelCase and add the suffix `Ch`, for example ``fastqFilesCh``.


Files
-----


Use camelCase, for example ``someScript.sh``.

For the scripts you develop and that are accessible in the ``bin/`` use the prefix **ap** (**a**\nalysis **p**\ipeline), for example ``apMyscript.sh``. This prefix makes it possible to distinguish the scripts you personally developed from those you retrieved from third parties.


Environment variables
---------------------

Use snake_case and lower case, for example ``my_global_var = "someValue"``.

