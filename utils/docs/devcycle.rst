.. _devcycle-page:

*****************
Development cycle
*****************


Prototyping
===========

First, configure your repository as explained here: :ref:`install-configure-file`. In general, this has to be done only once unless you want to change the options.

When prototyping the pipeline, we advice to use the :ref:`run-profile-multiconda` profile. As this stage, the containers should not be available thus making impossible to use the :ref:`run-profile-singularity` or :ref:`run-profile-docker` profiles.

We suggest that you provide test data and a ``conf/test.config`` file such that the pipeline can be tested on any modification of the source code for validation. Whenever possible, the test data must be as small as possible such that running the test does not take too much time.

Then, to install and test your modifications, just type ``make test_multiconda`` (see :ref:`install-test`) in the build directory. The first time this command is typed, the ``config`` files are automatically generated and installed. The configuration files will be regenerated whenever you modify the ``conf/base.config`` file (or whenever something is added or modified the both the ``recipes`` or ``modules`` directories).


.. |ko| image:: images/install.png
   :width: 25

.. |path| image:: images/path.png
   :width: 25


.. note::

   You can combine both the :ref:`run-profile-multiconda` with the :ref:`run-profile-path` profiles as described in the :ref:`run-combine-path-conda` section. This offers the possibility to install on your own all the software you need to setup the analysis methodology for the pipeline you are developing, in particular whenever you fall in any of the cases |ko| of |path| as described in the  :ref:`run-process-profile-table` table.

If you don't want any test to be started, just type ``make install``.



Whatever you use ``make test_multiconda`` (or any custom targets available in :ref:`install-test`) or ``make install``, only the files that have been modified will be installed that allows this step to be just a quick copy of the modified files in the install directory (if it is not necessary to generate the  ``config`` files).


.. important::

   **Why it is essential to deploy the pipeline in a dedicated directory and then test your modifications** rather than testing it directly from your source code directory in which you are developing?
   
   The deployement of the pipeline in a dedicated directory makes it possible to keep developing and modifying any file or to checkout any branch while a test is running especially when the test can take time. If you would launch a test from the source code directory the files could be modified while the test is running.

.. note::

   If you really prefer to launch your test in your source code directory (for good or bad reasons) you can still do it. In this case, you can either write and add the config files for the nextflow :ref:`run-profiles` as described in :ref:`profiles-page`  in the ``conf`` directory of copy them from config files automatically generated.

Containerizing
==============

Building the `singularity <https://sylabs.io/singularity/>`_ or `docker <https://www.docker.com/>`_ containers should start once the prototyping is over. Thus, the software developers will take care of:

* writing the recipes for any process that have a label falling in the :ref:`process-source-code` or :ref:`process-custom-install` categories,
* performing :ref:`process-resource` in order to optimize the informatic resource asked by the different processes.

Deployement
===========

Whoever you are, follow the guidelines describes in the :ref:`install-page` section.

