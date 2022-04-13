.. include:: substitutions.rst

.. _process-page:

*************
Add a process
*************

This section provides the guidelines for adding a new process in the ``main.nf`` file such that it allows the automatic generation of the ``config`` files and recipes to build the |singularity|_ and |docker|_ containers. Note that a geniac command line interface is provided to :ref:`cli-page` and ensure that the pipeline is compliant with the following guidelines.

.. note::

   All the examples below are taken from the |geniacdemo|_ pipeline. You can clone this repository and reproduce what is presented. This |geniacdemo|_ is fully functional.

Structure of a process
======================

.. important::

   Consider that **one** process invokes only **one** tool.

Each process must have a *label* directive. The *label* name may be different of the process name. For example:

::

   process fastqc {
     label 'fastqc'
     label 'lowMem'
     label 'lowCpu'
   
     tag "${prefix}"
     publishDir "${params.outDir}/fastqc", mode: 'copy'
   
     input:
     set val(prefix), file(reads) from rawReadsFastqcCh
   
     output:
     file "*_fastqc.{zip,html}" into fastqcResultsCh
     file "v_fastqc.txt" into fastqcVersionCh
   
     script:
     """
     fastqc -q $reads
     fastqc --version > v_fastqc.txt
     """
   }


Having a label is essential such that it makes it possible to automatically generate the configuration files ``conda.config``, ``multiconda.config``, ``singularity.config``, ``docker.config``, ``path.config`` and ``multipath.config``. This configuration files use the ``withLabel`` process selector. We will explain in the section :ref:`process-guidelines` that the name of the *label* must follow specific rules.

.. important::

   Pay a lot of attention to declare the *label* for each process since the automatic generation of configuration files mentionned above along with the singularity / docker recipes and containers relies on the label name by parsing the ``conf/geniac.config`` file from the source code.

.. note:: 

   Why we used ``withLabel`` rather than ``withName`` as process selector in the configutation files? Using ``withLabel`` offers the possibility to use the same exact same tool within two or more different processes with different options. This is a big advantage especially when you use containers as you don't have to build one container per process but the same container can be shared between processes.


Answer these questions first
============================

Where is the tool available?
----------------------------


`Is it just a standard Unix command?`
+++++++++++++++++++++++++++++++++++++


* `Yes`, it is something like `grep`, `sed`, `cat`, `etc.`, then see :ref:`process-unix`.

`Is it available in Conda?`
+++++++++++++++++++++++++++

* `Yes`, the tool is available in conda and can be easily installed from bioconda, conda-forge channels, then see :ref:`process-easy-conda`.

    
* `Yes`, but it cannot be easily installed as the order of the channels matters or it requires ``dependencies`` and/or ``pip`` directives in the conda recipe, then see :ref:`process-custom-conda`.


`Is it available only as a binary or as an executable script?`
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

* `Yes`, it is available as a binary (but without source code available) or as an executable script (shell, python, perl), then see :ref:`process-exec`.

`Is the source code available?`
+++++++++++++++++++++++++++++++

* `Yes`, then see :ref:`process-source-code`.

`Is it available as R packages?`
++++++++++++++++++++++++++++++++

* `Yes`, then see :ref:`renv-page`.

`Have you still not answered yes?`
++++++++++++++++++++++++++++++++++

Probably not, otherwise, you would not be reading this. This means that the tool can fall in any of these categories:

* it is provided as `deb`, `rpm` packages or any executable installer,
* it is a windows executable that needs mono to be run,
* it is whatever that needs a custom installation procedure.

Then see :ref:`process-custom-install`.


Does my tool require some environment variables to be set?
----------------------------------------------------------
  
If `Yes`, see :ref:`process-env-var`.

How many CPUs and memory resources does the tool require?
---------------------------------------------------------

See :ref:`process-resource` to define the informatics resources necessary to run your process.

.. _process-guidelines:

Guidelines
==========

.. _process-unix:

Standard UNIX command
---------------------


This is an easy one.

*prerequisite*
++++++++++++++

The command must work on standard UNIX system.

*label*
+++++++

Use always ``label 'onlyLinux'``

*example*
+++++++++

::

   process standardUnixCommand {
     label 'onlyLinux'
     label 'minMem'
     label 'minCpu'
     publishDir "${params.outDir}/standardUnixCommand", mode: 'copy'

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

Easy install with Conda
-----------------------

*prerequisite*
++++++++++++++

Of course, the tool has to be available in a conda channel.

Edit the file ``conf/geniac.config`` and add for example ``rmarkdown = "conda-forge::r-markdown=0.8=r351h96ca727_1003`` in the section ``params.geniac.tools`` as follows:

::

   params {
      geniac{
         tools {
            rmarkdown = "conda-forge::r-markdown=0.8=r351h96ca727_1003`
         }
      }
   }


The syntax follows the pattern from the conda package naming ``softName = "condaChannelName::softName=version=buildString"``.

Note that for some tools, other conda dependencies are required and can be added as follows:

::

   params {
      geniac{
         tools {
            fastqc = "conda-forge::openjdk=8.0.192=h14c3975_1003 bioconda::fastqc=0.11.6=2"
         }
      }
   }



*label*
+++++++

The *label* directive must have the exact same name as given in the ``params.geniac.tools`` section.

*example*
+++++++++

Add your process in the ``main.nf``. It can take any name (which is not necessarily the same name as the software that will be called on command line) provided it follows the :ref:`overview-naming`.

::

   process fastqc {
     label 'fastqc'
     label 'lowMem'
     label 'lowCpu'
   
     tag "${prefix}"
     publishDir "${params.outDir}/fastqc", mode: 'copy'
   
     input:
     set val(prefix), file(reads) from rawReadsFastqcCh
   
     output:
     file "*_fastqc.{zip,html}" into fastqcResultsCh
     file "v_fastqc.txt" into fastqcVersionCh
   
     script:
     """
     fastqc -q $reads
     fastqc --version > v_fastqc.txt
     """
   }


*container*
+++++++++++

In most of the case, you will have nothing to do. However, some tools depend on packages that have to be installed from the :ref:`linux-page`. For example, ``fastqc`` requires some fonts to be installed, then add the list of packages that will have to be installed with `dnf` (this is the Dandified YUM command which is the package management utility for the :ref:`linux-page`). To do so, edit the file ``conf/geniac.config`` and add for example ``fastqc = 'fontconfig dejavu*'`` in the section ``params.geniac.containers.yum`` as follows:

::

   geniac{
      containers {
         yum {
            fastqc = 'fontconfig dejavu*'
         }
      }
   }

.. warning::

   Be careful that you use the exact same name in ``params.geniac.containers.yum``, ``params.geniac.tools`` and *label* otherwise, the container will not work.

If you need to :ref:`customcmd-page`, this can be done using the following scopes associated to the *label* of the tool:

* ``params.geniac.containers.cmd.post``: to define commands which will be executed at the end of the default commands generated by geniac.
* ``params.geniac.containers.cmd.envCustom``: to define environment variables which will be set inside the docker and singularity images.

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
        - python=3.7.8=h6f2ec95_1_cpython
        - pip:
            - numpy==1.19.2


Edit the file ``conf/geniac.config`` and add for example ``trickySoftware = "${projectDir}/recipes/conda/trickySoftware.yml`` in the section ``params.geniac.tools`` as follows:

::

   geniac{
      tools {
         trickySoftware = "${projectDir}/recipes/conda/trickySoftware.yml"
      }
   }

*label*
+++++++

The *label* directive must have the exact same name as given in the ``params.geniac.tools`` section.

*example*
+++++++++

Add your process in the ``main.nf``. It can take any name (which is not necessarily the same name as the software that will be called on command line) provided it follows the :ref:`overview-naming`.

::

   process trickySoftware {
     label 'trickySoftware'
     label 'minMem'
     label 'minCpu'
     publishDir "${params.outDir}/trickySoftware", mode: 'copy'
   
     output:
     file "trickySoftwareResults.txt"
   
     script:
     """
     python --version > trickySoftwareResults.txt 2>&1
     """
   }

*container*
+++++++++++

In most of the case, you will have nothing to do. However, some tools depend on packages that have to be installed from the :ref:`linux-page`. For example, ``fastqc`` requires some fonts to be installed, then add the list of packages that will have to be installed with `dnf` (this is the Dandified YUM command which is the package management utility for the :ref:`linux-page`). To do so, edit the file ``conf/geniac.config`` and add for example ``fastqc = 'fontconfig dejavu*'`` in the section ``params.geniac.containers.yum`` as follows:

::

   geniac{
      containers {
         yum {
            myFavouriteTool = 'gsl blas'
         }
      }
   }

If you need to :ref:`customcmd-page`, this can be done using the following scopes associated to the *label* of the tool:

* ``params.geniac.containers.cmd.post``: to define commands which will be executed at the end of the default commands generated by geniac.
* ``params.geniac.containers.cmd.envCustom``: to define environment variables which will be set inside the docker and singularity images.

.. warning::

   Be careful that you use the exact same name in ``params.geniac.containers.yum``,  ``params.geniac.tools`` and *label*, otherwise, the container will not work.

.. _process-exec:

Binary or executable script
---------------------------

*prerequisite*
++++++++++++++

| The scripts or binaries must have been added in the ``bin/`` directory of the pipeline.
| They must have ``read`` and ``execute`` UNIX permissions. It must work on a UNIX system.

*label*
+++++++

Use ``label 'onlyLinux'`` if this is a bash script or define a new tool with the expected programming language to run the script of binary (e.g. ``label 'python'``).

*example*
+++++++++

Add your process in the ``main.nf``. It can take any name (which is not necessarily the same name as the software that will be called on command line) provided it follows the :ref:`overview-naming`.

::

   process execBinScript {
     label 'onlyLinux'
     label 'minMem'
     label 'minCpu'
     publishDir "${params.outDir}/execBinScript", mode: 'copy'
   
     output:
     file "execBinScriptResults_*"
   
     script:
     """
     apMyscript.sh > execBinScriptResults_1.txt
     someScript.sh > execBinScriptResults_2.txt
     """
   }

.. note::

   ``apMyscript.sh`` is so named with `ap` prefix since it has been developed for the pipeline while ``someScript.sh`` does not have this prefix as it is a third-party script (see :ref:`overview-naming`).

*container*
+++++++++++

You have nothing to do, the install process will build the recipes and images for you.

.. _process-source-code:

Install from source code
------------------------

*prerequisite*
++++++++++++++

First, you have to retrieve the source code and add it in a directory in the ``modules/fromSource`` directory. Create the ``modules/fromSource`` directory if needed. For example, add the source code of the ``helloWorld`` tool in ``modules/fromSource/helloWorld`` directory. This directory can be added as a |gitsubmodule|_ `(see this tutorial) <https://biogitflow.readthedocs.io/en/latest/git.html#add-a-submodule-in-a-repository>`_.

Then comes the tricky part. Add in the file :download:`modules/fromSource/CMakeLists.txt <../data/modules/fromSource/CMakeLists.txt>` the |cmakeexternalproject|_  function from |cmake|_.

::

   ExternalProject_Add(
       helloWorld
       SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/helloWorld
       CMAKE_ARGS
           -DCMAKE_INSTALL_PREFIX=${CMAKE_BINARY_DIR}/externalProject/bin)

.. important::

   Always use the variable ``${CMAKE_CURRENT_SOURCE_DIR}`` in the ``SOURCE_DIR`` directive, for example ``SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/helloWorld``

   Always install the binary in ``${CMAKE_BINARY_DIR}/externalProject/bin)`` (note that ``CMAKE_BINARY_DIR`` is actually the build directory you have created to configure and build the pipeline, see :ref:`install-page`).

.. important::

   Always create another ``CMakeLists.txt`` file in the folder which stores the source code of the tool. For example, create the ``modules/fromSource/helloWorld/CMakeLists.txt`` file which will explain how the source code must be installed. Depending on the source code you added, refer to the |cmake|_ documentation to correctly write the ``CMakeLists.txt`` file.

.. note::

   Installation from source code offers a great flexibility as the software developer can control everything during the installation process. However, this obviously requires more configuration. In particular, the software developer has to be fluent with |cmake|_ in order to tackle specific use cases, see :ref:`from-source-examples-page` for more details.

*label*
+++++++

The label will be the same name as the directory you added the source code, for example ``helloWorld``.

*example*
+++++++++

Add your process in the ``main.nf``. It can take any name (which is not necessarily the same name as the software that will be called on command line) provided it follows the :ref:`overview-naming`.

::

   process helloWorld {
     label 'helloWorld'
     label 'minMem'
     label 'minCpu'
     publishDir "${params.outDir}/helloWorld", mode: 'copy'
   
     output:
     file "helloWorld.txt" into helloWorldOutputCh
   
     script:
     """
     helloWorld > helloWorld.txt
     """
   }

*container*
+++++++++++

You have nothing to do, the install process will build the recipes and images for you.

If you need to :ref:`customcmd-page`, this can be done using the following scopes associated to the *label* of the tool:

* ``params.geniac.containers.cmd.post``: to define commands which will be executed at the end of the default commands generated by geniac.
* ``params.geniac.containers.cmd.envCustom``: to define environment variables which will be set inside the docker and singularity images.

   
.. _process-custom-install:
   
Custom install
--------------

*prerequisite*
++++++++++++++

Create a folder in ``recipes/dependencies/`` with the label of your tool, for example ``recipes/dependencies/alpine``. Add in this folder your installer file (`deb`, `rpm` or whatever) in the ``recipes/dependencies/`` directory along with any other files that could be needed especially to build the container.

*label*
+++++++

Choose any name you want.

*example*
+++++++++

Add your process in the ``main.nf``. It can take any name (which is not necessarily the same name as the software that will be called on command line) provided it follows the :ref:`overview-naming`.

::

   process alpine {
     label 'alpine'
     label 'minMem'
     label 'minCpu'
     publishDir "${params.outDir}/alpine", mode: 'copy'
   
     input:
     val x from oneToFiveCh
   
     output:
     file "alpine_*"
   
     script:
     """
     source ${projectDir}/env/alpine.env
     echo "Hello from alpine: \$(date). This is very high here: \${PEAK_HEIGHT}!" > alpine_${x}.txt
     """
   }

*container*
+++++++++++

This is the only case you will have to write the recipe yourself. The recipe should have the same name as the label with the suffix being either ``.def`` for singularity and ``.Dockerfile`` for docker. Save your recipes the folders ``recipes/singularity`` and ``recipes/docker`` respectively. For example, the ``alpine.def`` recipe looks like this:

::

   Bootstrap: docker
   From: alpine:3.7
   
   %setup
       mkdir -p ${SINGULARITY_ROOTFS}/opt
   
   %files
       alpine/myDependency.sh /opt/myDependency.sh
   
   %post
       apk update
       apk add bash
       bash /opt/myDependency.sh
   
   %environment
       export LC_ALL=C
       export PATH=/usr/games:$PATH

The ``alpine.Dockerfile`` recipe looks like this:

::

   FROM alpine:3.7
   
   RUN mkdir -p /opt
   
   ADD alpine/myDependency.sh /opt/myDependency.sh
   
   RUN apk update
   RUN apk add bash
   RUN bash /opt/myDependency.sh
   
   ENV LC_ALL C
   ENV PATH /usr/games:$PATH



.. important::

   As your recipe will very likely depends on files you added for example in the ``recipes/dependencies/alpine`` directory, you can just mention the name of the files in the ``%files`` section for `singularity` or with the ``ADD`` directive for `docker` include the name of the label, for example ``alpine/myDependency.sh``.


.. _process-env-var:

Environment variables
---------------------


Shared between processes
++++++++++++++++++++++++

*prerequisite*

If the environment variable will be used by several processes, add it in the ``conf/base.config`` file in the *env* scope as follows:

::

   env {
       MY_GLOBAL_VAR = "someValue"
   }

*example*

The script ``apMyscript.sh`` uses ``MY_GLOBAL_VAR``:

::

   #! /bin/bash
   
   echo "This is a script I have developed for the pipeline."
   echo "MY_GLOBAL_VAR: ${MY_GLOBAL_VAR}"


This script is called in the following process:

::

   process execBinScript {
     label 'onlyLinux'
     label 'minMem'
     label 'minCpu'
     publishDir "${params.outDir}/execBinScript", mode: 'copy'
   
     output:
     file "execBinScriptResults_*"
   
     script:
     """
     apMyscript.sh > execBinScriptResults_1.txt
     someScript.sh > execBinScriptResults_2.txt
     """
   }

Process specific
++++++++++++++++

*prerequisite*

Add a file with the name of your process and the extension ``.env`` in the folder ``env/``. For example, add ``env/alpine.env``:

::

   #!/bin/bash
   
   # required environment variables for alpine
   PEAK_HEIGHT="4810m" 
   
   export PEAK_HEIGHT

*example*

In your process, source the ``env/alpine.env`` and then use the variable you defined:


::

   process alpine {
     label 'alpine'
     label 'minMem'
     label 'minCpu'
     publishDir "${params.outDir}/alpine", mode: 'copy'
   
     input:
     val x from oneToFiveCh
   
     output:
     file "alpine_*"
   
     script:
     """
     source ${projectDir}/env/alpine.env
     echo "Hello from alpine: \$(date). This is very high here: \${PEAK_HEIGHT}!" > alpine_${x}.txt
     """
   }

.. _process-resource:

Resource tuning
---------------

Anything related to process are defined in ``conf/process.config``. 


Shared between processes
++++++++++++++++++++++++

You can define generic labels for both CPU and memory (as you wish) in the file ``conf/process.config``. For example:

::

  withLabel: minCpu { cpus = 1 }
  withLabel: lowCpu { cpus = 2 }
  withLabel: medCpu { cpus = 4 }
  withLabel: highCpu { cpus = 8 }
  withLabel: extraCpu { cpus = 16 }

  withLabel: minMem { memory = 1.GB }
  withLabel: lowMem { memory = 2.GB }
  withLabel: medMem { memory = 8.GB }
  withLabel: highMem { memory = 16.GB }
  withLabel: extraMem { memory = 32.GB }

Then, in any process, you can just set any label you need. For example:

::

   process execBinScript {
     label 'onlyLinux'
     label 'minMem'
     label 'minCpu'
     publishDir "${params.outDir}/execBinScript", mode: 'copy'
   
     output:
     file "execBinScriptResults_*"
   
     script:
     """
     apMyscript.sh > execBinScriptResults_1.txt
     someScript.sh > execBinScriptResults_2.txt
     """
   }


Process specific
++++++++++++++++

To optimize the resources used in a computing cluster, you may want to finely tune the CPU and memory asked by the process. Do do so, define the process selector ``withName`` in the file ``conf/process.config`` for your process of interest. For example:

::

  withName:outputDocumentation {
    memory = { checkMax( 100.MB, 'memory' ) }
  }

.. tip::

   To assess what are the amount of resources used by you process refers to the `Metrics section <https://www.nextflow.io/docs/latest/metrics.html>`_ fron the |nextflow|_ documentation.

Results
=======

Use the ``publishDir`` directive with the ``${params.outDir}`` parameters and organize your results as you wish. For example:

::

   publishDir "${params.outDir}/execBinScript", mode: 'copy'

