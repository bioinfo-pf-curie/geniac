.. _naming-page:

******
Basics
******



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

