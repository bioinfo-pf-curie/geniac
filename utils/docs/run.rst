.. _run-page:

****************
Run the pipeline
****************


For specific options of the analysis pipeline, use the `README`.

Profiles
========

Set where the tools are available
---------------------------------

.. _run-profile-standard:

standard
++++++++

This is the default profile used when ``-profile`` is not specified when you launch `nextflow`. This profile requires that all the tools are available in your path.


*example*

::

   nextflow -c conf/test.config run main.nf

.. warning::

   If two different processes require the same tool but with different versions, this profile will not work. Thus, you will have to use :ref:`run-profile-multiconda`, :ref:`run-profile-singularity`, :ref:`run-profile-docker` or :ref:`run-profile-path` profiles.

.. _run-profile-conda:

conda
+++++

When using this profile, `nextflow` creates a conda environment from the recipe `environment.yml`.
The conda environment is created in the `$HOME/conda-cache-nextflow` directory by default unless you set the directory with the option ``--condaCacheDir`` from the command line when you launch `nextflow`.

*example*

::

   nextflow -c conf/test.config run main.nf -profile conda --condaCacheDir "$HOME/myCondaCacheDir"

.. note::

   The conda environment is created the first time th pipeline is started.

.. warning::

   Only tools that are compatible with each other can be added in the conda recipe ``environment.yml``.

.. _run-profile-multiconda:

multiconda
++++++++++

When using this profile, `nextflow` creates several conda environments: for every tools that are specified in the ``params.tool`` section from the ``conf/base.config`` file, one conda environment is created in the `$HOME/conda-cache-nextflow` directory by default unless you set the directory with the option ``--condaCacheDir`` from the command line when you launch `nextflow`. This profile make it possible to use conda even if some tools are not compatible with each other.

*example*

::

   nextflow -c conf/test.config run main.nf -profile multiconda

.. note::

   The conda environment is created the first time th pipeline is started.
.. _run-profile-singularity:


singularity
+++++++++++

This profile allows the usage of the singularity containers. This profile will work in any case.

*example*

::

   nextflow -c conf/test.config run main.nf -profile singularity


.. _run-profile-docker:

docker
++++++

This profile allows the usage of the singularity containers. This profile will work in any case.

*example*

::

   nextflow -c conf/test.config run main.nf -profile singularity

.. _run-profile-path:

path
++++

On the pipeline is installed, the following directory tree is created in the install directory:

::

   path/alpine/bin
   path/fastqc/bin
   path/helloWorld/bin
   path/rmarkdown/bin
   path/trickySoftware/bin

This directory tree follows the pattern ``path/labelOfTheTool/bin`` meaning that every tool has a specific directory having the name of its label. When using the ``path`` profile, ``path/labelOfTheTool/bin`` directory is automatically included in the PATH of only the process that has the corresponding label. 

Therefore, this profile make it possible to tackle any configuration such as using the same tool but with different versions.

If the tool require is alreadyinstalled on your system, you can just add a symlink. For example:

::

   ls -s /usr/bin/fastqc path/fastqc/bin

Alternatively, you can also do the following:

::

   rm path/fastqc/bin
   ln -s /usr/bin path/fastqc



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

   The `executor <https://www.nextflow.io/docs/latest/executor.html>`_ used is the one that has been set during :ref:`install-page` with the  `ap_nf_executor` configure option (or default is nothing was specified). If you want to change the executor, just edit the ``conf/cluster.config`` file in the install directory and set the ``executor`` to whatever `nextflow` supports.

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
   :header: "Process", "standard", "conda", "multiconda", "singularity", "docker", "path"
   :widths: 10, 10, 10, 10, 10, 10, 10

   ":ref:`process-unix`", |ok|, |ok|, |ok|, |ok|, |ok|, |ok|
   ":ref:`process-source-code`", |ok|, |ok|, |ok|, |ok|, |ok|, |ok|
   ":ref:`process-exec`", |ok|, |ok|, |ok|, |ok|, |ok|, |ok|
   ":ref:`process-easy-conda`", |ko|, |ok|, |ok|, |ok|, |ok|, |path|
   ":ref:`process-custom-conda`", |ko|, |ko|, |ok|, |ok|, |ok|, |path|
   ":ref:`process-custom-install`", |ko|, |ko|, |ko|, |ok|, |ok|, |path|

| |ok| the tool will be available after install or first run of the pipeline
| |ko| the tool must in your ``$PATH``
| |path| the tool must be in the ``path/`` of the install directory (see :ref:`run-profile-path` for details)

Options
=======

General options
---------------

condaCacheDir
+++++++++++++

queue
+++++

singularityImagePath
++++++++++++++++++++

singularityRunOptions
+++++++++++++++++++++

dockerRunOptions
++++++++++++++++


Analysis options
----------------

They are defined in the ``conf/tools.config`` file. Refer to the *README* of the pipeline for details.


Examples
========

Default
-------

If all the tools are available in your path, just launch:

::

   nextflow -c conf/test.config run main.nf -profile multiconda

.. _run-combine-path-conda:

Combine path profile with conda/multiconda
------------------------------------------

We see from the :ref:`run-process-profile-table` table that, if you use the :ref:`run-profile-multiconda` profile and one tool falls in the :ref:`process-custom-install` category, the workflow will fail unless the tool is already installed and available in your ``$PATH``. You also have the possibility to add the tool ins the ``path/`` of the install directory (see :ref:`run-profile-path` for details). To illustrate this, let's try the following:

::

   nextflow -c conf/test.config run main.nf -profile multiconda

Of course, it works.

Then, make the ``helloWorld`` tool unavaible: 

::

   cd ..
   mv pipeline/bin/helloWorld path/helloWorld/helloWorld
   cd -
   nextflow -c conf/test.config run main.nf -profile multiconda

Of course, it fails: ``.command.sh: line 2: helloWorld: command not found``.

Thus try:

::

   nextflow -c conf/test.config run main.nf -profile multiconda,path

Of course, it works!

.. note::

   This example with the ``helloWorld`` tool is not the most relevant as this tool is available whaterver the profile you use (see :ref:`run-process-profile-table`) but it is just here to show that it is possible to combine profiles to make sure that all the tools will be available.

Set options in command line for the tools
-----------------------------------------


All options in ``conf/tools.path`` can be set in command line. For example:

::

   nextflow -c conf/test.config run main.nf -profile multiconda --trickySoftwareOpts "'--help'"


