.. include:: substitutions.rst

.. _check-page:

**************
Check the code
**************

This section describes how to install and use the geniac command line interface to check that the guidelines to :ref:`process-page` have been correctly implemented.

Install the geniac linter
=========================

::

   conda create -n geniac-cli python=3.9
   conda activate geniac-cli
   pip install git+https://github.com/bioinfo-pf-curie/geniac.git

Launch the geniac linter
========================


::

   geniac lint /PATH/TO/DIRECTORY


For more options run ``geniac -h`` and ``geniac lint -h``.
