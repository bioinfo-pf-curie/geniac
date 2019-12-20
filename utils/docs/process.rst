.. _process-page:

*************
Add a process
*************

This section provides the guidelines for adding a new process in the ``main.nf`` file.

Structure of a process
======================

Its is important to consider that **one** process invokes only **one** tool.

Each process must have a `*label*` directive. The `*label*` name may be different of the process name. For example:

::

   process outputDocumentation {
     label 'rmarkdown'
     publishDir "${params.summaryDir}", mode: 'copy'
   
     input:
     file outputDocs from OutputDocsCh
   
     output:
     file "resultsDescription.html"
   
     script:
     """
     markdownToHtml.r $outputDocs resultsDescription.html
     """
   }


Having a label is essential such that it makes it possible to automatically generate the configuration files ``conda.config``, ``multiconda.config``, ``singularity.config``, ``docker.config`` and ``path.config``. This configuration files use the ``withLabel`` process selector. We will explain in the section :ref:`process-guidelines` that the name of the `*label*` must follow specific rules.

.. important::

   Pay a lot of attention to declare the `*label*` for each process since automatic generation of configuration files mentionned above along with the singularity / docker recipes and containers relies on the label name by parsing the ``conf/base.config`` file from the source code.

.. note:: 

   Why we used ``withLabel`` rather than ``withName`` as process selector in the configutation files? Using ``withLabel`` offers the possibility to use the same exact same tool within two or more different processes with different options. This is a big advantage especially when you use containers as you don't have to build one container per process but the same container can be shared between processes.


Answer these questions first
============================

Where the tool is available?
----------------------------


`Is it just a standard unix command?`
+++++++++++++++++++++++++++++++++++++


* `Yes`, it is something like `grep`, `sed`, `cat`, `etc.`, then see :ref:`process-unix`.

`Is it available in conda?`
+++++++++++++++++++++++++++

* `Yes`, the tool is available in conda and can be easily installed from bioconda, conda-forge channels, then see :ref:`process-easy-conda`.

    
* `Yes`, but it cannot be easily installed as the order of the channels matters or it requires ``dependencies`` and/or ``pip`` directives in the conda recipe, then see :ref:`process-custom-conda`.


`Is it available only as a binary or as an executable script?`
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

* `Yes`, it is available as a binary (but without source code available) or as an executable script (shell, python, perl), then see :ref:`process-exec`

`Is the source code available?`
+++++++++++++++++++++++++++++++

* `Yes`, then see :ref:`process-source-code`.

`Do you have still not answered yes?`
+++++++++++++++++++++++++++++++++++++

Probably not, otherwise, you would not be reading this. This means that the tool can fall in any of these categories:

* it is provided as `deb`, `rpm` packages or any executable installer
* it is a windows executable that needs mono to be run
* it is whatever that needs a custom installation procedure

Then see :ref:`process-custom-install`.

Does my tool require some environment variables to be set?
----------------------------------------------------------
  
If `Yes`, see :ref:`process-env-var`.

How many cpu and memory resources does the tool require?
--------------------------------------------------------

See :ref:`process-resource` to define the informatics resources necessary to run your process.

.. _process-guidelines:

Guidelines
==========

.. _process-unix:

Standard unix command
---------------------


This is an easy one.

*prerequisite*
++++++++++++++

The command must work on standard unix system.

*label*
+++++++

Use always ``label 'onlyLinux'``

*example*
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

*container*
+++++++++++

You have nothing to do, the install process will build the recipes and images for you.


.. _process-easy-conda:

Easy install with conda
-----------------------

*prerequisite*
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



*label*
+++++++

The `*label*` directive must have the exact same name as given in the ``params.tools`` section.

*example*
+++++++++

Add your process in the ``main.nf``. It can take any name (which is not necessarly the same name as the software that will be called on command line) provided it follows the :ref:`naming-page`.

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


*container*
+++++++++++

In most of the case, you will have nothing to do. However, some tools depend on packages that have to be installed from the CentOS distribution we use to build the container. For example, ``fastqc`` requires some fonts to be installed, then add the list of packages that will have to be installed with `yum` (which is the package management utility for CentOS). To do so, edit the file ``conf/base.config`` and add for example ``fastqc = 'fontconfig dejavu*'`` in the section ``params.containers`` as follows:

::

   containers {
     yum {
             fastqc = 'fontconfig dejavu*'
         }
   }

.. warning::

   Be careful that you use the exact same name in ``containers.yum``, ``params.tools`` and `*label*` otherwise, the container will not work.

.. _process-custom-conda:

Custom install with conda
-------------------------

*prerequisite*
++++++++++++++

Of course, the tool has to be available in a conda channel.

Write the custom conda recipe in the directory ``recipes/conda``, for example add the file ``trickySoftware.yml``:

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

*label*
+++++++

The `*label*` directive must have the exact same name as given in the ``params.tools`` section.

*example*
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

*container*
+++++++++++

In most of the case, you will have nothing to do. However, some tools depend on packages that have to be installed from the CentOS distribution we use to build the container. For example, if ``myFavouriteTool`` requires maths libraries like `gsl` and `blas`, then add the list of packages that will have to be installed with `yum` (which is the package management utility for CentOS). To do so, edit the file ``conf/base.config`` and add for example ``myFavouriteTool = 'gsl blas'`` in the section ``params.containers`` as follows:


::

   containers {
     yum {
             myFavouriteTool = 'gsl blas'
         }
   }

.. warning::

   Be careful that you use the exact same name in ``containers.yum``,  ``params.tools`` and `*label*`, otherwise, the container will not work.

.. _process-exec:

Binary or executable script
---------------------------

*prerequisite*
++++++++++++++

| The scripts or binaries must have been added in the ``bin/`` directory of the pipeline.
| They must have ``read`` and ``execute`` unix permissions. It must work on a unix system.

*label*
+++++++

Use always ``label 'onlyLinux'``.

*example*
+++++++++

Add your process in the ``main.nf``. It can take any name (which is not necessarly the same name as the software that will be called on command line) provided it follows the :ref:`naming-page`.

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

   ``apMyscript.sh`` is so named with `ap` prefix since it has been developed for the pipeline while ``someScript.sh`` does not have this prefix as it is a third-party script (see :ref:`naming-page`).

*container*
+++++++++++

You have nothing to do, the install process will build the recipes and images for you.

.. _process-source-code:

Install from source code
------------------------

*prerequisite*
++++++++++++++

First, you have to retrieve the source code and add it in a directory in the ``modules`` directory. For example, add the source code of the ``helloWorld`` tool in ``modules/helloWorld`` directory. This directory can be added as a `git submodule <https://git-scm.com/docs/git-submodule>`_.

Then comes the tricky part. Add in the file ``modules/CMakeLists.txt`` the `ExternalProject_Add <https://cmake.org/cmake/help/latest/module/ExternalProject.html>`_  function from `cmake <https://cmake.org>`_.


::

   ExternalProject_Add(
       helloWorld
       SOURCE_DIR ${CMAKE_SOURCE_DIR}/modules/helloWorld
       CMAKE_ARGS
           -DCMAKE_INSTALL_PREFIX=${CMAKE_BINARY_DIR}/externalProject/bin)


.. note::

   Depending on the source code you added, the arguments of the `ExternalProject_Add <https://cmake.org/cmake/help/latest/module/ExternalProject.html>`_  function may be different. Refer to the documentation for more details. 

.. important::

   Always install the binary in ``${CMAKE_BINARY_DIR}/externalProject/bin)``.

*label*
+++++++

The label will be the same name as the directory you added the source code, for example ``helloWorld``.

*example*
+++++++++

Add your process in the ``main.nf``. It can take any name (which is not necessarly the same name as the software that will be called on command line) provided it follows the :ref:`naming-page`.

::

   process helloWorld {
     label 'helloWorld'
     label 'smallMem'
     label 'smallCpu'
     publishDir "${params.outputDir}/helloWorld", mode: 'copy'
   
   
     output:
     file "helloWorld.txt" into helloWorldOutputCh
   
     script:
     """
     helloWorld > helloWorld.txt
     """
   }

*container*
+++++++++++

In order to have the container automatically built, you have to add an additional shell script in the ``modules`` directory with the suffixe ``.sh`` (otherwise it will not work) and with the exact same name as the directory in which you added the source code. For example, you added the source code in ``helloWorld`` directory, thus the shell script must be named ``helloWorld.sh``, and write the code that has to be executed to compile and install the binary:

::

   ### executable must always be installed in /usr/local/bin
   yum install -y cmake3
   mkdir build
   cd build || exit
   cmake3 ../helloWorld -DCMAKE_INSTALL_PREFIX=/usr/local/bin
   make
   make install

.. important::

   * Consider that this shell script will be executed in the ``modules`` directory,
   * Use only relative path
   * This script will be executed in CentOS distribution, thus install any required packages with ``yum``,
   * Set always the install directory to ``/usr/local/bin``.

Any suggestion to avoid having both in the `ExternalProject_Add <https://cmake.org/cmake/help/latest/module/ExternalProject.html>`_ function and this shell script is very welcome.
   
   .. _process-custom-install:
   
Custom install
--------------

*prerequisite*
++++++++++++++

Add your installer file (`deb`, `rpm` or whatever) in the ``recipes/dependencies/`` directory along with any other files that could be needed especially to build the container.

*label*
+++++++



*example*
+++++++++

Add your process in the ``main.nf``. It can take any name (which is not necessarly the same name as the software that will be called on command line) provided it follows the :ref:`naming-page`.

::

   process alpine {
     label 'alpine'
     label 'smallMem'
     label 'smallCpu'
     publishDir "${params.outputDir}/alpine", mode: 'copy'
   
     input:
     val x from oneToFiveCh
   
     output:
     file "alpine_*"
   
   
     script:
     """
     source ${baseDir}/env/alpine.env
     echo "Hello from alpine: \$(date). This is very high here: \${PEAK_HEIGHT}!" > alpine_${x}.txt
     """
   }

*container*
+++++++++++

This is the only case you will have to write the recipe yourself. The recipe should have the same name as the label with the suffixe being either ``.def`` for singularity and ``.Dockerfile`` for docker. For example, the ``alpine.def`` recipe looks like this:

::

   Bootstrap: docker
   From: alpine:3.7
   
   %setup
       mkdir -p ${SINGULARITY_ROOTFS}/opt
   
   %files
       myDependency.sh /opt/myDependency.sh
   
   %post
       apk update
       apk add bash
       bash /opt/myDependency.sh
   
   %environment
       export LC_ALL=C
       export PATH=/usr/games:$PATH

.. important::

   As your recipe will very likely depends on files you added in the ``recipes/dependencies/`` directory, you can just mention the name of the files in the ``%files`` section for `singularity` or with the ``ADD`` directive for `docker`.

Tool options
------------

.. _process-env-var:

Environment variables
---------------------

Process specific
++++++++++++++++

*prerequisite*

Add a file with the name of your process and the extention ``.env`` in the folder ``env/``. For example, add ``env/alpine.env``:

::

   #!/bin/bash
   
   # required environment variables for alpine
   peak_height="4810m" 
   
   export peak_height

*example*

In your process, source the ``env/alpine.env`` and then use the variable you defined:


::

   process alpine {
     label 'alpine'
     label 'smallMem'
     label 'smallCpu'
     publishDir "${params.outputDir}/alpine", mode: 'copy'
   
     input:
     val x from oneToFiveCh
   
     output:
     file "alpine_*"
   
   
     script:
     """
     source ${baseDir}/env/alpine.env
     echo "Hello from alpine: \$(date). This is very high here: \${peak_height}!" > alpine_${x}.txt
     """
   }

Shared between processes
++++++++++++++++++++++++

*prerequisite*

If the environment variable will be used by several processes, add it in the ``conf/base.config`` file in the *env* scope as follows:

::

   env {
       my_global_var = "someValue"
   }

*example*

The script ``apMyscript.sh`` uses ``my_global_var``:

::

   #! /bin/bash
   
   echo "This is a script I have developed for the pipeline."
   echo "my_global_var: ${my_global_var}"


This script is called in the following process:

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


.. _process-resource:


Resource tuning
---------------



