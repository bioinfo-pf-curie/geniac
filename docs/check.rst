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
   pip install git+https://github.com/bioinfo-pf-curie/geniac.git@release

Launch the geniac linter
========================


::

   geniac lint /PATH/TO/DIRECTORY


.. tip::
   The default configuration file for the geniac linter is available in the file ``src/geniac/conf/geniac.ini``. It defines which files are parsed and what is checked by the geniac linter. You can pass a custom file to the linter using the ``-c`` option.

For more options run ``geniac -h`` and ``geniac lint -h``.
