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

To use the containers, ate least one of the following software is required:

* `singularity <https://sylabs.io/singularity/>`_ >= 3.2
* `docker <https://www.docker.com/>`_ >= 18.0

.. _overview-source-tree:

Structure of the source code directory tree
===========================================

The source code is organized as follows:

::

   ├── assets
   ├── bin
   ├── conf
   │   └── templates
   ├── docs
   ├── env
   ├── modules
   │   └── helloWorld
   ├── recipes
   │   ├── conda
   │   ├── dependencies
   │   ├── docker
   │   └── singularity
   ├── test
   │   └── data
   └── utils
       ├── cmake
       ├── docs
       │   ├── images
       │   └── _themes
       │       └── sphinx_rtd_theme
       └── install

The guidelines and additional utilities we developed are in the ``utils`` folder.


.. _overview-naming:

Naming convention
=================

Variables
---------


Use camelCase.


Channels
--------


Use camelCase and add the suffix `Ch`, for example ``fastqFilesCh``.


Files
-----


Use camelCase.

For the scripts you develop and that are accessible in the ``bin/`` use the prefix **ap** (**a**\nalysis **p**\ipeline). This prefix makes it possible to distinguish the scripts you personally developed from those you retrieved from third parties.


Environment variables
---------------------

Use snake_case and lower case.

Git branch model
================

ADD DETAILS


