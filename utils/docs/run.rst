.. _run-page:

****************
Run the pipeline
****************


For specific options of the analysis pipeline, use the `README`.

Profiles
========

.. _run-profile-conda:

conda
-----

.. _run-profile-multiconda:

multiconda
----------

.. _run-profile-singularity:

singularity
-----------


.. _run-profile-docker:

docker
------

.. _run-profile-path:

path
----

cluster
-------

Examples
========

.. |ok| image:: images/installed.png
   :width: 30

.. |ko| image:: images/install.png
   :width: 30

.. |path| image:: images/path.png
   :width: 30

.. _run-process-profile-table:

.. csv-table:: Process types and profiles
   :header: "Process", "standard", "conda", "multiconda", "singularity", "docker", "path"
   :widths: 5, 10, 10, 10, 10, 10, 10

   ":ref:`process-unix`", |ok|, |ok|, |ok|, |ok|, |ok|, |ok|
   ":ref:`process-source-code`", |ok|, |ok|, |ok|, |ok|, |ok|, |ok|
   ":ref:`process-exec`", |ok|, |ok|, |ok|, |ok|, |ok|, |ok|
   ":ref:`process-easy-conda`", |ko|, |ok|, |ok|, |ok|, |ok|, |path|
   ":ref:`process-custom-conda`", |ko|, |ko|, |ok|, |ok|, |ok|, |path|
   ":ref:`process-custom-install`", |ko|, |ko|, |ko|, |ok|, |ok|, |path|

| |ok| the tool will be available after install or first run of the pipeline
| |ko| the tool must in your ``$PATH``
| |path| the tool must be in the ``path/`` of the install directory (see :ref:`run-profile-path` for details)

Combine path profile with conda/multiconda
------------------------------------------

We see from the :ref:`run-process-profile-table` table that, if you use the :ref:`run-profile-multiconda` profile and one tool falls in the :ref:`process-custom-install` category, the workflow will fail unless the tool is already installed and available in your ``$PATH``. You also have the possibility to add the tool ins the ``path/`` of the install directory (see :ref:`run-profile-path` for details). To illustrate this, let's try the following:

::

   nextflow -c conf/test.config run main.nf -profile multiconda

Off course, it works.

Then, make the ``helloWorld`` tool unavaible: 

::

   cd ..
   mv pipeline/bin/helloWorld path/helloWorld/helloWorld
   cd -
   nextflow -c conf/test.config run main.nf -profile multiconda

Off course, it fails: ``.command.sh: line 2: helloWorld: command not found``.

Thus try:

::

   nextflow -c conf/test.config run main.nf -profile multiconda,path

Off course, it works!

.. note::

   This example with the ``helloWorld`` tool is not the most relevant as this tool is available whaterver the profile you use (see :ref:`run-process-profile-table`) but it is just here to show that it is possible to combine profiles to make sure that all the tools will be available.


