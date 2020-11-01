.. include:: substitutions.rst

.. _run-page:

****************
Run the pipeline
****************


Here, we only describe the general guidelines tun run any pipeline. For specific options of the analysis pipeline, refer to the `README.md` dedicated to the pipeline you want to run.


.. _run-profiles:

Profiles
========

Set where the tools are available
---------------------------------


.. _run-profile-conda:

conda
+++++

When using this profile, `nextflow` creates a |conda|_ environment from the recipe ``environment.yml``.
The conda environment is created in the ``${HOME}/conda-cache-nextflow`` directory by default unless you set the directory with the option ``--condaCacheDir`` from the command line when you launch `nextflow`.

*example*

::

   nextflow -c conf/test.config run main.nf -profile conda --condaCacheDir "${HOME}/myCondaCacheDir"

.. note::

   The conda environment is created the first time the pipeline is started.

.. warning::

   Only tools that are compatible with each other can be added in the conda recipe ``environment.yml``.

.. _run-profile-docker:

docker
++++++

This profile allows the usage of the |docker|_ containers. This profile will work in any case (provided that you have root credentials to run docker).

*example*

::

   nextflow -c conf/test.config run main.nf -profile docker

.. _run-profile-multiconda:

multiconda
++++++++++

When using this profile, `nextflow` creates several |conda|_ environments: for every tools that are specified in the ``params.tool`` section from the ``conf/geniac.config`` file, one |conda|_ environment is created in the ``${HOME}/conda-cache-nextflow`` directory by default unless you set the directory with the option ``--condaCacheDir`` from the command line when you launch `nextflow`. This profile make it possible to use |conda|_ even if some tools are not compatible with each other.

*example*

::

   nextflow -c conf/test.config run main.nf -profile multiconda --condaCacheDir "${HOME}/myCondaCacheDir"

.. note::

   The conda environments are created the first time the pipeline is started.

.. _run-profile-multipath:

multipath
+++++++++

Once the pipeline is installed, the following directory tree is created in the install directory:

::

   multipath/alpine/bin
   multipath/fastqc/bin
   multipath/helloWorld/bin
   multipath/rmarkdown/bin
   multipath/trickySoftware/bin

This directory tree follows the pattern ``multipath/labelOfTheTool/bin`` meaning that every tool has a specific directory having the name of its label. When using the ``multipath`` profile, ``multipath/labelOfTheTool/bin`` directory is automatically included in the PATH of only the process that has the corresponding label.

Therefore, this profile makes it possible to tackle any configuration such as using the same tool but with different versions.

If the tool required is already installed on your system, you can just add a symlink. For example:

::

   ls -s /usr/bin/fastqc multipath/fastqc/bin

Alternatively, you can also do the following:

::

   rm -r multipath/fastqc/bin
   ln -s /usr/bin multipath/fastqc/bin

If the tool is not present on your system, just install it in the dedicated folder.

.. _run-profile-path:

path
++++

Once the pipeline is installed, the following directory tree is created in the install directory:

::

   path/bin

When using the ``path`` profile, ``path/bin`` directory is automatically included in the PATH of every process.

If the tool required is already installed on your system, you can just add a symlink. For example:

::

   ls -s /usr/bin/fastqc path/bin

Alternatively, assuming than some tools are already present in ``/usr/bin``, you can do the following:

::

   rm -r path/bin
   ln -s /usr/bin path/bin

If the tool is not present on your system, just install it in the dedicated folder.

.. _run-profile-singularity:

singularity
+++++++++++

This profile allows the usage of the |singularity|_ containers. This profile will work in any case.

*example*

::

   nextflow -c conf/test.config run main.nf -profile singularity


.. _run-profile-standard:

standard
++++++++

This is the default profile used when ``-profile`` is not specified when you launch `nextflow`. This profile requires that all the tools are available in your path.


*example*

::

   nextflow -c conf/test.config run main.nf

.. warning::

   If two different processes require the same tool but with different versions, this profile will not work. Thus, you will have to use :ref:`run-profile-multiconda`, :ref:`run-profile-singularity`, :ref:`run-profile-docker` or :ref:`run-profile-multipath` profiles.

Set where the computation will take place
-----------------------------------------


local
+++++

This is the default.

.. _run-profile-cluster:

cluster
+++++++

If you want to launch the pipeline on a computing cluster, just launch:

::

   nextflow -c conf/test.config run main.nf -profile multiconda,cluster

.. important::

   The `executor <https://www.nextflow.io/docs/latest/executor.html>`_ used is the one that has been set during :ref:`install-page` with the  ``ap_nf_executor`` configure option (or default is nothing was specified). If you want to change the executor, just edit the ``conf/cluster.config`` file in the install directory and set the ``executor`` to whatever `nextflow` supports.

.. tip::

   If you want your job to be submitted on a specific ``queue``, use the option ``--queue`` with the name of the queue in the command line as follows:
   
   ``nextflow -c conf/test.config run main.nf -profile multiconda,cluster --queue q_medium``

Compatibility between process types and profiles
------------------------------------------------

Depending on the process type, the tool is not available with all the different profiles. We provide here the different configurations that cam occur.

.. |ok| image:: images/installed.png
   :width: 25

.. |ko| image:: images/install.png
   :width: 25

.. |path| image:: images/path.png
   :width: 25

.. _run-process-profile-table:

.. csv-table:: Process types and profiles
   :header: "Process", "standard", "conda", "multiconda", "singularity", "docker", "multipath", "path"
   :widths: 10, 10, 10, 10, 10, 10, 10, 10

   ":ref:`process-unix`", |ok|, |ok|, |ok|, |ok|, |ok|, |ok|, |ok|
   ":ref:`process-source-code`", |ok|, |ok|, |ok|, |ok|, |ok|, |ok|, |ok|
   ":ref:`process-exec`", |ok|, |ok|, |ok|, |ok|, |ok|, |ok|, |ok|
   ":ref:`process-easy-conda`", |ko|, |ok|, |ok|, |ok|, |ok|, |path|, |path|
   ":ref:`process-custom-conda`", |ko|, |ko|, |ok|, |ok|, |ok|, |path|, |path|
   ":ref:`process-custom-install`", |ko|, |ko|, |ko|, |ok|, |ok|, |path|, |path|

| |ok| the tool will be available after install or first run of the pipeline
| |ko| the tool must in your ``${PATH}``
| |path| the tool must be in the ``path/`` (or ``multipath``) folder of the install directory (see :ref:`run-profile-multipath` and :ref:`run-profile-path` for details)

Options
=======

General options
---------------


--condaCacheDir
+++++++++++++++

Whenever you use the :ref:`run-profile-conda` or :ref:`run-profile-multiconda` profiles, the |conda|_ environments are created in the ``${HOME}/conda-cache-nextflow`` folder by default. This folder can be changed using the ``--condaCacheDir`` option. For example:

::

   nextflow -c conf/test.config run main.nf -profile multiconda --condaCacheDir "${HOME}/myCondaCacheDir"

\\-\\-globalPath
++++++++++++++++

When you use :ref:`run-profile-path` or :ref:`run-profile-multipath` profiles, the ``path`` and ``multipath`` folders are located in the installation directory by default (see :ref:`install-structure-dir-tree`). The ``--globalPath`` option allows the path of the ``path`` and ``multipath`` folders to be changed at runtine. For example:


::

   nextflow -c conf/test.config run main.nf -profile multipath --globalPath "${HOME}/myGlobalPath"

.. _run-option-outdir:

\\-\\-outDir
++++++++++++

The output directory where the results will be saved. For example:

::

   nextflow -c conf/test.config run main.nf -profile multipath --outDir "${HOME}/myResults"

\\-\\-queue
+++++++++++

If you want your job to be submitted on a specific ``queue`` when you use the :ref:`run-profile-cluster`, use the option ``--queue`` with the name of the queue in the command line. For example:


\\-\\-singularityImagePath
++++++++++++++++++++++++++

When you use the :ref:`run-profile-singularity` profile, the  |singularity|_ containers are located in the installation directory in the folder ``containers/singularity`` by default (see :ref:`install-structure-dir-tree`). The ``--singularityImagePath`` option allows the path of the ``containers/singularity`` folder to be change at runtine. For example:

::

   nextflow -c conf/test.config run main.nf -profile singularity --singularityImagePath "${HOME}/mySingularityImagePath"

Analysis options
----------------

Refer to the *README* of the pipeline for details.

Results
=======

To better organize your results, we recommned that use use the variable ``${params.outDir}`` in every process with the ``publishDir`` directive. For example:

::

   publishDir "${params.outDir}/fastqc", mode: 'copy'

Note that the ``--outDir`` option defines where you want to store the results (see :ref:`run-option-outdir`). In the directory, the ``results`` folder gathers all the results. If no option is provided, the ``results`` will be created where the ``main.nf`` file is located.

Analysis
--------

The ``results`` folder contains the results of each tools. For example:

::

   results/
   ├── alpine
   │   ├── alpine_1.txt
   │   ├── alpine_2.txt
   │   ├── alpine_3.txt
   │   ├── alpine_4.txt
   │   └── alpine_5.txt
   ├── execBinScript
   │   ├── execBinScriptResults_1.txt
   │   └── execBinScriptResults_2.txt
   ├── fastqc
   │   ├── SRR1106775-25K_1_fastqc.html
   │   ├── SRR1106775-25K_1_fastqc.zip
   │   ├── SRR1106775-25K_2_fastqc.html
   │   ├── SRR1106775-25K_2_fastqc.zip
   │   ├── SRR1106776-25K_1_fastqc.html
   │   ├── SRR1106776-25K_1_fastqc.zip
   │   ├── SRR1106776-25K_2_fastqc.html
   │   ├── SRR1106776-25K_2_fastqc.zip
   │   └── v_fastqc.txt
   ├── helloWorld
   │   └── helloWorld.txt
   ├── MultiQC
   │   ├── report_data
   │   │   ├── multiqc_data.json
   │   │   ├── multiqc_fastqc.txt
   │   │   ├── multiqc_general_stats.txt
   │   │   ├── multiqc.log
   │   │   └── multiqc_sources.txt
   │   ├── report.html
   │   └── samplePlan.csv
   ├── standardUnixCommand
   │   └── bonjourMonde.txt
   ├── trickySoftware
   │   └── trickySoftwareResults.txt

Moreover, the following information will be systematically generated whatever the process you added in the ``main.nf`` file:

::

   results/
   ├── softwareVersions
   │   └── softwareVersions_mqc.yaml
   ├── summary
   │   ├── pipelineReport.html
   │   ├── pipelineReport.txt
   │   ├── resultsDescription.html
   └── workflowOnComplete.txt

Trace
-----

`The nextflow tracing information <https://www.nextflow.io/docs/latest/tracing.html>`_ will also be available:

::

   results/
   ├── summary
   │   └── trace
   │       ├── DAG.pdf
   │       ├── report.html
   │       ├── timeline.html
   │       └── trace.txt



Examples
========

Default
-------

If all the tools are available in your path, just launch:

::

   nextflow -c conf/test.config run main.nf -profile multiconda

.. _run-combine-path-conda:

Combine path/multipath profile with conda/multiconda
----------------------------------------------------

We see from the :ref:`run-process-profile-table` table that, if you use the :ref:`run-profile-multiconda` profile and one tool falls in the :ref:`process-custom-install` category, the workflow will fail unless the tool is already installed and available in your ``${PATH}``. You also have the possibility to add the tool ins the ``path/`` of the install directory (see :ref:`run-profile-multipath` for details). To illustrate this, let's try the following:

::

   nextflow -c conf/test.config run main.nf -profile multiconda

Of course, it works.

Then, make the ``helloWorld`` tool unavailable: 

::

   cd ..
   mv pipeline/bin/helloWorld path/helloWorld/bin/helloWorld
   cd -
   nextflow -c conf/test.config run main.nf -profile multiconda

Of course, it fails: ``.command.sh: line 2: helloWorld: command not found``.

Thus try:

::

   nextflow -c conf/test.config run main.nf -profile multiconda,multipath

Of course, it works!

.. note::

   This example with the ``helloWorld`` tool is not the most relevant as this tool is available whatever the profile you use (see :ref:`run-process-profile-table`) but it is just here to show that it is possible to combine profiles to make sure that all the tools will be available.

