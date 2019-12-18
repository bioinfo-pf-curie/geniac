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

Where the tool is available?
----------------------------


`Is it just a standard unix command?`
+++++++++++++++++++++++++++++++++++++


* `Yes`, it is something like `grep`, `sed`, `cat`, `etc.`, then see :ref:`process-unix`.

`Is it available in conda?`
+++++++++++++++++++++++++++

* `Yes`, the tool is available in conda and can be easily installed from bioconda, conda-forge channels, then :ref:`process-easy-conda`.

    
* `Yes`, but it cannot be easily installed as the order of the channels matters or it requires ``dependencies`` and/or ``pip`` directives in the conda recipe, then :ref:`process-custom-conda`.


`Is it available only as a binary or as an executable script?`
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

* `Yes`, it is available as a binary (but without source code available) or as an executable script (shell, python, perl), then see :ref:`process-exec`

`Is the source code available?`
+++++++++++++++++++++++++++++++

* `Yes`, then see :ref:`process-source-code`.

`Do you have still not answered yes?`
+++++++++++++++++++++++++++++++++++++

Probably not otherwise, you would not be reading this. This means that the tool can fall in any of these categories:

* it is provided as deb, rpm packages or any executable installer
* it is a windows executable that needs mono to be run
* no matter what it is whatever, it needs a custom installation procedure

Then see :ref:`process-custom-install`.

Does my tool require some environment variables to be set?
----------------------------------------------------------
  
If `Yes`, see :ref:`process-env-var`.

How many cpu and memory resources does the tool require?
--------------------------------------------------------

`See` :ref:`process-resource` to define the informatics resources necessary to run your process.


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

.. _process-easy-conda:

Easy install with conda
-----------------------

`prerequisite`
++++++++++++++

Of course, the tool has to be available in a conda channel.

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

Add your process in the ``main.nf``. It can take any name (which is not necessarly the same name as the software will be called on command line) provided it follows the :ref:`naming-page`.

::

   process outputDocumentation {
     label 'rmarkdown'
     publishDir "${params.summaryDir}", mode: 'copy'
   
     input:
     file outputDocs from chOutputDocs
   
     output:
     file "resultsDescription.html"
   
     script:
     """
     markdownToHtml.r $outputDocs resultsDescription.html
     """
   }


`container`
+++++++++++

In most of the case, you will have nothing to do. However, some tools depend on packages that have to be installed from the CentOS distribution we use to build the container. For example, ``fastqc`` requires some fonts to be installed, then add the list of packages that will have to be install with `yum` (which is the package management utility for CentOS)

::

   containers {
     yum {
             fastqc = 'fontconfig dejavu*'
         }
   }

.. warning::

   Be careful that you use the exact same name in ``containers.yum``, ``params.tools`` otherwise, the container will not work.

.. _process-custom-conda:

Custom install with conda
-------------------------

`prerequisite`
++++++++++++++

Of course, the tool has to be available in a conda channel.

Write the custom conda recipe in the directory ``pipeline/recipes/conda``, for example add the file ``trickySoftware.yml``:

::

   name: trickySoftware_env
   channels:
       - bioconda
       - conda-forge
       - defaults
   dependencies:
       - python=2.7.13=1
       - pip:
           - pysam==0.11.2.2
           - numpy==1.13.1
   

Edit the file ``conf/base.config`` and add for example ``trickySoftware = "${baseDir}/recipes/conda/trickySoftware.yml`` in the section ``params.tools`` as follows:

::

   tools {
     trickySoftware = "${baseDir}/recipes/conda/trickySoftware.yml"
   }

`label`
+++++++

The ``label`` directive must have the exact same name as given in the ``params.tools`` section.

`example`
+++++++++

Add your process in the ``main.nf``. It can take any name (which is not necessarly the same name as the software that will be called on command line) provided it follows the :ref:`naming-page`.

::

   process trickySoftware {
     label 'trickySoftware'
     label 'smallMem'
     label 'smallCpu'
     publishDir "${params.outputDir}/trickySoftware", mode: 'copy'
   
     output:
     file "trickySoftwareResults.txt"
   
     script:
     """
     python ${params.trickySoftwareOpts} > trickySoftwareResults.txt 2>&1
     """
   }

`container`
+++++++++++

In most of the case, you will have nothing to do. However, some tools depend on packages that have to be installed from the CentOS distribution we use to build the container. For example, if ``myFavouriteTool`` requires some maths librarie `gsl` and `blas`, then add the list of packages that will have to be install with `yum` (which is the package management utility for CentOS)

::

   containers {
     yum {
             myFavouriteTool = 'gsl blas'
         }
   }

.. warning::

   Be careful that you use the exact same name in ``containers.yum``,  ``params.tools`` and ``label``, otherwise, the container will not work.

.. _process-exec:

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

.. _process-source-code:

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

.. _process-custom-install:

Custom install
--------------

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

.. _process-env-var:

Environment variables
---------------------

.. _process-resource:


Resource tuning
---------------



