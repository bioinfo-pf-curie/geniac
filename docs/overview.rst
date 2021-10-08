.. include:: substitutions.rst

.. _overview-page:

***********
Get started
***********


This section just provides a general overview of the guidelines for the structure of the source code directory and the naming conventions. The most important guidelines are detailed in the :ref:`process-page` section.

.. important::

   It is important to note that the |geniacrepo|_ relies on the structure of the |geniactemplate|_ while the |geniactemplate|_ could work without the |geniacrepo|_ (provided that you generate manually the missing :ref:`profiles-page`).
   
   It means also that this documentation explains how the |geniactemplate|_ works with the |geniacrepo|_. 
   
   All the examples shown in the documentation are taken from the |geniacdemo|_. You can clone this repository and reproduce what is presented.

Prerequisites
=============

The following software are required:

* a Linux distribution
* |nextflow|_ >= 20.01.0
* |git|_  >= 2.0
* |gitlfs|_
* |cmake|_ >= 3.0
* |make|_ >= 4.1

To use the containers, at least one of the following software is required:

* |singularity|_ >= 3.2
* |docker|_ >= 18.0

.. _overview-source-tree:

Test geniac on the geniac-demo pipeline
=======================================

As a quick start, you can try the |geniacdemo|_ pipeline as follows:

::

   export WORK_DIR="${HOME}/tmp/myPipeline"
   export INSTALL_DIR="${WORK_DIR}/install"
   export GIT_URL="https://github.com/bioinfo-pf-curie/geniac-demo.git"
   
   geniac init ${WORK_DIR} ${GIT_URL}
   geniac install ${INSTALL_DIR}
   geniac test multiconda

Start a new repository
======================

The best way to initiate your repository is to create a new |git|_ project from the |geniactemplate|_. Indeed, `geniac` expects that the repository contains specific folders and files that are already set up in the template. However, you can use `geniac` on an existing repository and you can follow the procedure described in the :ref:`faq-page`.


.. _overview-naming:

Naming convention
=================

Variables
---------


Use camelCase, for example ``outDir = './results'``.


Channels
--------


Use camelCase and add the suffix `Ch`, for example ``fastqFilesCh``.


Files
-----


Prefer camelCase (whenever possible as some tools expect specific pattern such as |multiqc|_ like ``_mqc`` suffix), for example ``someScript.sh``.

For the scripts you develop and that are accessible in the ``bin/`` use the prefix **ap** (**a**\nalysis **p**\ipeline), for example ``apMyscript.sh``. This prefix makes it possible to distinguish the scripts you personally developed from those you retrieved from third parties.


Environment variables
---------------------

Use snake_case and upper case, for example ``MY_GLOBAL_VAR = "someValue"``.

