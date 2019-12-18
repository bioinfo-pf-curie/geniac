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

.. tip:: 

   Why we used ``withLabel`` rather than ``withName`` in the configutation files? Using ``withLabel`` offers the possibility to use the same exact same tool within two or more different processes with different options. This is a big advantage especially when you use containers as you don't have to build one container per process but the same container can be used.


Answer these questions first
============================

* Is my tool just a standard unix command (grep, sed, cat, etc.)?

    * Yes: :ref:`process-unix` see LINKWWW (-> onlylinux = notools)

* Is my tool available in conda?

    * Yes: my tool is available in conda and can be easily installed from bioconda, conda-force channels: see LINKXXX (-> add the tool in params.tools in conf/base.config)

    * Yes: but it cannot be easily installed as the order of the channels matters or it requires the ``dependencies`` or the ``pip`` directives in the conda recipe: see LINKYYY (-> create a yml file with the conda recipe in recipes/conda/)

* Is my tools available only as a binary (but without source code available) or as an executable script (shell, python, perl) 

   * Yes: see LINKZZZ (-> put the binary or executable script in bin/)

* Is my the source code of my tool available?

   * Yes: see LINKAAA (-> put the source in modules/)

* Does my tool require some environment variables to be set?

  * Yes: see LINK

* Does my tool require the cpu and memory resource to be customized?

  * Yes: see LINK

Guidelines
==========

.. _process-unix:

Standard unix command
---------------------


This is an easy one.

`prerequisite`
++++++++++++++

The command must work on standard unix system.

`label`
+++++++

Use always ``label 'onlyLinux'``

`example`
+++++++++

::

   /*
    * process with onlylinux (standard unix command)
    */
   
   process standardUnixCommand {
     label 'onlyLinux'
     label 'smallMem'
     label 'smallCpu'
     publishDir "${params.outputDir}/standardUnixCommand", mode: 'copy'
   
     input:
     file hello from helloWorldOutputCh
   
     output:
     file "bonjourMonde.txt"
   
     script:
     """
     sed -e 's/Hello World/Bonjour Monde/g' ${hello} > bonjourMonde.txt
     """
   }

`container`
+++++++++++

You have nothing to do, the install process will build the recipes and images for you.

.. note::

   Container are built using CentOS 7 distribution.

Easy install with conda
-----------------------

`prerequisite`
++++++++++++++

Edit the file ``conf/base.config`` and add for example ``rmarkdown = "conda-forge::r-markdown=0.8"`` in the section ``params.tools`` as follows:

::

   params {
       tools {
           rmarkdown = "conda-forge::r-markdown=0.8"
       }
   }


The syntax follows the patterm ``softName = "condaChannelName::softName=version"``.

Note that for some tools, other conda dependencies are required and can be added as follows:

::

   params {
     tools {
       fastqc = "conda-forge::openjdk=8.0.192=h14c3975_1003 bioconda::fastqc=0.11.6=2"
     }
   }



`label`
+++++++

The ``label`` directive must have the exact same name as given in the ``params.tools`` section.

`example`
+++++++++

Add your process in the `main.nf`, it can take any name provided in follows the :ref:`naming-page`.

Note that the name of the software provided in `params.tools` can be anyname (is it not necessarly the same name as the software will be called in command line).

`container`
+++++++++++

Custom install with conda
-------------------------

`prerequisite`
++++++++++++++

`label`
+++++++

`example`
+++++++++

`container`
+++++++++++

Binary or executable script
---------------------------

`prerequisite`
++++++++++++++

| The scripts or binaries must have been added in the ``bin/`` of the pipeline.
| They must have ``read`` and ``execute`` unix permissions.

`label`
+++++++

Use always ``label 'onlyLinux'``.

`example`
+++++++++

::

   /*
    * process with onlyLinux (invoke scripts from bin/ directory) 
    */
   
   process execBinScript {
     label 'onlyLinux'
     label 'smallMem'
     label 'smallCpu'
     publishDir "${params.outputDir}/execBinScript", mode: 'copy'
   
     output:
     file "execBinScriptResults_*"
   
     script:
     """
     apMyscript.sh > execBinScriptResults_1.txt
     someScript.sh > execBinScriptResults_2.txt
     """
   }

.. note::

   ``apMyscript.sh`` is so named with `ap` prefix since it has been developed for the pipeline while ``someScript.sh`` is a third-party script (see :ref:`naming-page`).

`container`
+++++++++++

You have nothing to do, the install process will build the recipes and images for you.

Install from source code
------------------------

`prerequisite`
++++++++++++++

`label`
+++++++

`example`
+++++++++

`container`
+++++++++++


Tool options
------------


Environment variables
---------------------


Resource tuning
---------------



