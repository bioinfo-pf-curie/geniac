.. _basic-page:

******
Basics
******

Prerequisites
=============

* `nextflow <https://www.nextflow.io/>`_ >= 19.10.0
* `git <https://git-scm.com/>`_  >= 2.0
* `git lfs <https://git-lfs.github.com/>`_
* `cmake <https://cmake.org/>`_ >= 3.0
* `singularity <https://sylabs.io/singularity/>`_ >= 3.2
* `docker <https://www.docker.com/>`_ >= 18.0

.. _basic-source-tree:

Structure of the source code directory tree
===========================================

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


.. _basic-naming:

Naming convention
=================

Variables
---------


Use camelCase.


Channels
--------


Use camelCase and add the suffixe `Ch`, for example ``fastqFilesCh``.


Files
-----


Use camelCase.

For the scripts you develop and that are accessible in the ``bin/`` use the prefix **ap** (**a**\nalysis **p**\ipeline). This prefix makes it possible to distinguish the scripts you personnally developed from those you retrieved from third parties.


Environment variables
---------------------

Use snake_case and lower case.

Git branch model
================

ADD DETAILS


