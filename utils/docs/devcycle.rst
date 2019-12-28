.. _devcycle-page:

*****************
Development cycle
*****************


Prototyping
===========

First, configure your repository as explained here: :ref:`install-configure-file`. In general, this has to be done only once unless you want to change the options.

When protyping the pipeline, we advice to use the :ref:`run-profile-multiconda` profile. As this stage, the containers should not be available thus making impossible to use the :ref:`run-profile-singularity` or :ref:`run-profile-docker`.

We suggest that you provide test data and a ``conf/test.config`` file such that the pipeline can be tested on any modification of the source code for validation. Whenever possible, the test data must be as small as possible such that running the test does not take too much time.

Then, to install and test your modification, just type ``make test_multiconda`` (see :ref:`install-test`) in the build directory. The first time this command is typed, the ``config`` files are automatically generated and installed. The configuration files will be regenerated whenever you modify the ``conf/base.config`` file. 

If you don't want any test to be started, just type ``make install``.


Whatever you use ``make test_multiconda`` (or any custom targets available in :ref:`install-test`) or ``make install``, only the files that have been modified will be installed that allows this step to be just a quick copy of the modified files in the install directory (if it is not necessary to generate the  ``config`` files).
