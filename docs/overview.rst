.. include:: substitutions.rst

.. _overview-page:

***********
Get started
***********


This section just provides a general overview of the guidelines for the structure of the source code directory and the naming conventions. The most important guidelines are detailed in the :ref:`process-page` section.

Prerequisites
=============

The following software are required:

* |nextflow|_ >= 20.01.0
* |git|_  >= 2.0
* |gitlfs|_
* |cmake|_ >= 3.0

To use the containers, at least one of the following software is required:

* |singularity|_ >= 3.2
* |docker|_ >= 18.0

.. _overview-source-tree:


Start a new repository
======================

The best way to initiate your repository is to create a new |git|_ project from the |geniactemplate|_. However, you can use geniac on an existing repository and you can follow the procedure described in the :ref:`faq-page`.


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

