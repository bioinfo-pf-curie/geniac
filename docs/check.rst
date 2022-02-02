.. include:: substitutions.rst

.. _check-page:

**************
Check the code
**************

This section describes how to install and use the geniac Command Line Interface (CLI) to check that the guidelines to :ref:`process-page` have been correctly implemented.

Install the geniac command line interface
=========================================

::

   conda create -n geniac-cli python=3.10
   conda activate geniac-cli
   pip install git+https://github.com/bioinfo-pf-curie/geniac.git@release

Launch the geniac linter
========================


::

   geniac lint /PATH/TO/DIRECTORY


.. tip::
   The default configuration file for the geniac linter is available in the file ``src/geniac/conf/geniac.ini``. It defines which files are parsed and what is checked by the geniac linter. You can pass a custom file to the linter using the ``-c`` option.

For more options run ``geniac -h`` and ``geniac lint -h``.

Geniac CLI examples
===================

Geniac Command Line Interface comes with several options to initiate, install and test a pipeline:

::

   export WORK_DIR="${HOME}/tmp/myPipeline"
   export INSTALL_DIR="${WORK_DIR}/install"
   export GIT_URL="https://github.com/bioinfo-pf-curie/geniac-demo.git"

   # Initialization of a working directory
   # with the src and build folders
   geniac init -w ${WORK_DIR} ${GIT_URL}
   cd ${WORK_DIR}

   # Install the pipeline with the singularity images
   geniac install . ${INSTALL_DIR} -m singularity
   sudo chown -R  $(id -gn):$(id -gn) build

   # Test the pipeline with the singularity profile
   geniac test singularity

   # Test the pipeline with the singularity and cluster profiles
   geniac test singularity --check-cluster
