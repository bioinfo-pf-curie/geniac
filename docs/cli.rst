.. include:: substitutions.rst

.. _cli-page:

**********
Geniac CLI
**********

This section describes how to install and use the geniac Command Line Interface (CLI).

Install the geniac command line interface
=========================================

::

   # Create the geniac conda environment (use conda >= 4.12.0)
   export GENIAC_CONDA="https://raw.githubusercontent.com/bioinfo-pf-curie/geniac/release/environment.yml"
   wget ${GENIAC_CONDA}
   conda env create -f environment.yml
   conda activate geniac

.. tip::
   All the geniac CLI comes with the ``-v`` option (verbosity) which can be useful to describes what runs the command step by step.

Initiate a geniac working directory
===================================

::

   # Initialization of a working directory
   # with the src and build folders
   geniac init -w ${WORK_DIR} ${GIT_URL}
   cd ${WORK_DIR}

.. _cli-lint:

Check the code with the geniac linter
=====================================

Once in the geniac working directory, you can check that the guidelines to :ref:`process-page` have been correctly implemented.

::

   cd ${WORK_DIR}
   geniac lint


You can also provide a path to the source code of your pipeline:

::

   geniac lint /PATH/TO/DIRECTORY


.. tip::
   The default configuration file for the geniac linter is available in the file ``src/geniac/conf/geniac.ini``. It defines which files are parsed and what is checked by the geniac linter. You can pass a custom file to the linter using the ``-c`` option.

For more options run ``geniac -h`` and ``geniac lint -h``.

.. _cli-singularity-build:

Install the pipeline with the singularity images
================================================

::

   # Install the pipeline with the singularity images
   cd ${WORK_DIR}
   geniac install . ${INSTALL_DIR} -m singularity

This installation requires `sudo` privileges. Another alternative is to use the fakeroot option provided that the system administrator allowed you to use this option.

::

   # Install the pipeline with the singularity images
   cd ${WORK_DIR}
   geniac install . ${INSTALL_DIR} -m singularityfakeroot

For more options run ``geniac install -h``.


Install the pipeline using existing singularity images
======================================================

::

   # Install the pipeline using existing singularity images
   cd ${WORK_DIR}
   geniac install . ${INSTALL_DIR} --ap_singularity_image_path=/path/to/singularity/images

For more options run ``geniac install -h``.

.. _cli-configs:

Generate the configuration files
================================

::

   # Generate the config files
   cd ${WORK_DIR}
   geniac configs

The config files will be available in the folder ``${WORK_DIR}/configs``

.. _cli-recipes:

Generate the container recipes
==============================

::

   # Generate the container recipes
   cd ${WORK_DIR}
   geniac recipes

The config files will be available in the folder ``${WORK_DIR}/recipes`` for both docker and singularity.

If you want to generate and install the container recipes do:

::

   # Generate and install the container recipes
   cd ${WORK_DIR}
   geniac install . ${INSTALL_DIR} --ap_install_singularity_recipes --ap_install_docker_recipes

Test the pipeline with the singularity profile
==============================================

::

   # Test the pipeline with the singularity profile
   cd ${WORK_DIR}
   geniac test singularity

Test the pipeline with the singularity and cluster profiles
===========================================================

::

   # Test the pipeline with the singularity profile
   cd ${WORK_DIR}
   geniac test singularity --check-cluster

Clean the geniac work directory
===============================

You can clean the build directory as follows:

::

   # Clean the build directory
   cd ${WORK_DIR}
   geniac clean

List available cmake options
============================


::

   # List available cmake options
   cd ${WORK_DIR}
   geniac options
