.. include:: substitutions.rst

.. _renv-page:

***************************************************
R with reproducible environments using renv package
***************************************************

The `renv <https://rstudio.github.io/renv/>`_ package helps you to create reproducible environments for your `R projects <https://www.r-project.org>`_. The ``renv.lock`` lockfile records the state of your project’s private library, and can be used to restore the state of that library as required. ``geniac`` can use a ``renv.lock`` lockfile to install all the package dependencies needed by your R environment. However, this is a use case which requires some manual configuration as explained below. ``geniac`` allows you to add as many tools as you wish using ``renv``. In this section, we provide an example using a tool with the label ``renvGlad``.

.. important::

    For any tool using ``renv``, its label must have the prefix ``renv``!

Create a conda recipe
======================

Create the conda recipes in the folder ``recipes/conda`` which defines which R version you want to use, for example create ``recipes/conda/renvGlad.yml`` as follows:

::

    name: renvGlad
    channels:
        - conda-forge
        - bioconda
        - defaults
    dependencies:
        - r-base=4.3.1=h29c4799_3


Add the label in geniac.config
==================================

In the section ``params.geniac.tools`` of the file ``conf/geniac.config``, add the label with the three scopes ``yml``, ``env`` and ``bioc``, for example:

::

          renvGlad {
            yml = "${projectDir}/recipes/conda/renvGlad.yml"
            env = "${params.condaCacheDir}/custom_renvGlad"
            bioc = "3.17"
          }


* ``renvGlad.yml`` provides the path to the conda recipe. It should be located in ``"${projectDir}/recipes/conda"``.
* ``renvGlad.env`` defines the name of the environment in the conda cache dir.
* ``renvGlad.bioc`` sets the Bioconductor version which is possibly required to install the R packages.

Create a process to init the renv
=================================

This process allows the usage of the R software with the ``multiconda`` and ``conda`` profiles. During this process, the dependencies provided in the ``renv.lock`` will be installed. The process ``renvInit`` is provided with the documentation: copy the code :download:`renvInit <../data/nf-modules/local/process/renvInit.nf>` into the file ``nf-modules/local/process/renvInit.nf``:



.. literalinclude:: ../data/nf-modules/local/process/renvInit.nf


In your ``main.nf``, include the file  ``./nf-modules/local/process/renvInit.nf`` as a nextflow module. The module should be included using a prefix wich is the same as the name of the label of the process that will use `renv <https://rstudio.github.io/renv/>`_. In this example, we will consider that the process ``glad`` has the label ``renvGlad``. Therefore, ``renvInit`` module is included as ``renvGladInit`` (i.e. concatenate the label name with ``Init`` suffix):

::

    include { renvInit as renvGladInit } from './nf-modules/local/process/renvInit'


Then, in your ``main.nf``:

* invoke the nextflow module ``renvGladInit`` using the label of the tool ``'renvGlad'`` as an argument
* call the process ``glad`` taking as an argument the output of the process ``renvInitGlad``

::

    renvGladInit('renvGlad')
    glad(renvGladInit.out.renvInitDone)


If you have several processes using `renv <https://rstudio.github.io/renv/>`_, do the extact same procedure just using the other label name of your other process.

Copy you ``renv.lock`` file  is a sublder inside ``recipes/dependencies/``
==========================================================================

We assume that the reader is familiar with `renv <https://rstudio.github.io/renv/>`_. In the folder ``recipes/dependencies/``, create a subfolder with the name of the label of the tool, for example ``recipes/dependencies/renvGald``. Then, copy your ``renv.lock`` file in this subfolder . Here is an example of a ``renv.lock`` file:

.. literalinclude:: ../data/recipes/dependencies/renvGlad/renv.lock



Add a process which uses the renv
=================================

Write you process using the label with the ``renv`` tool and always define in the ``input`` section of the ``val renvInitDone``

::

    process glad {
      label 'renvGlad'
      label 'minCpu'
      label 'lowMem'
      publishDir "${params.outDir}/GLAD", mode: 'copy'
    
      input:
      val renvInitDone
    
      output: 
      path "BkpInfo.tsv"
    
      script:
      """
      Rscript ${projectDir}/bin/apGlad.R
      """
    }
