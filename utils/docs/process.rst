.. _process-page:

*************
Add a process
*************

Structure of a process
======================

Its is important to consider that **one** process invokes only **one** tool.

Each process must have a ``label`` directive. The ``label`` name may be different of the process name.

Having a label is essential such that it makes it possible to automatically generate the configuration files ``conda.config``, ``multiconda.config``, ``singularity.config``, ``docker.config`` and ``path.config``. This configuration files use the ``withLabel``. We will explain in the next section that the name of the ``label`` will follow specific rules.

.. warning::

   Pay a lot of attention to declare the ``label`` for each process since automatic generation of config files, singularity / docker recipes and containers relies on the label name by parsing the files from the source code.


Answer these questions first
============================

* Is my tool just a standard unix command (grep, sed, cat, etc.)?

    * Yes: see LINKWWW (-> onlylinux = notools)

* Is my tool available in conda?

    * Yes: my tool is available in conda and can be easily installed from bioconda, conda-force channels: see LINKXXX (-> add the tool in params.tools in conf/base.config)

    * Yes: but it cannot be easily installed as the order of the channels matters or it requires the ``dependencies`` or the ``pip`` directives in the conda recipe: see LINKYYY (-> create a yml file with the conda recipe in recipes/conda/)

* Is my tools available only as a binary (but without source code available) or as an executable script (shell, python, R, etc) 

   * Yes: see LINKZZZ (-> put the binary or executable script in bin/)

* Is my the source code of my tool available?

   * Yes: see LINKAAA (-> put the source in modules/)

* Does my tool require some environment variables to be set?

  * Yes: see LINK

* Does my tool require the cpu and memory resource to be customized?

  * Yes: see LINK

Guidelines
==========

Standard unix command
---------------------


Easy install with conda
-----------------------


Custom install with conda
-------------------------


Binary or executable script
---------------------------

Install from source code
------------------------


Environment variables
---------------------


Resource tuning
---------------



