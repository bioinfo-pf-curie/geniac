.. include:: substitutions.rst

.. _renv-page:

***************************************************
R with reproducible environments using renv package
***************************************************

The `renv <https://rstudio.github.io/renv/>`_ package helps you to create reproducible environments for your R projects. The ``renv.lock`` lockfile records the state of your project’s private library, and can be used to restore the state of that library as required. ``geniac`` can use a ``renv.lock`` lockfile to install all the package dependencies needed by your R environment. However, this is a use case which requires some manual configuration as explained below.

Create a conda recipe
======================

Create the conda recipes in the file ``recipes/conda/r.yml`` which defines which R version you want to use, for example:

::

   name: r_env
   channels:
       - conda-forge
       - bioconda
       - defaults
   dependencies:
       - r-base=3.6.1=h6e652e1_3


Add the label 'r' in geniac.config
==================================

In the section ``params.geniac.tools`` of the file ``conf.geniac.config``, add the label ``r`` with the two scopes ``base`` and ``label`` as follows:

::

            r {
                base = "${projectDir}/recipes/conda/r.yml"
                label = "${params.condaCacheDir}/custom_r"
            }

``r.base`` provides the path to the conda recipe while ``r.label`` defines the name of the environment in the conca cache dir.

Create a process initRenv
=========================

In your ``main.nf``, add the following process:

::

    process initRenv {
        label 'onlyLinux'
        label 'smallCpu'
        label 'memM'
    
        output:
        val(true) into doneCh
    
        script:
        if (workflow.profile.contains('multiconda')) {
            """
            if conda env list | grep -wq ${params.geniac.tools.r.label} || [ -d "${params.condaCacheDir}" -a -d "${params.geniac.tools.r.label}" ] ; then
                echo "prefix already exists, skipping environment creation"
            else
                CONDA_PKGS_DIRS=. conda env create --prefix ${params.geniac.tools.r.label} --file ${params.geniac.tools.r.base}
            fi
    
            source ${params.conda.activate}
            set +u
            conda activate ${params.geniac.tools.r.label}
            set -u
    
            export PKG_CONFIG_PATH=\$(dirname \$(which conda))/../lib/pkgconfig
            export PKG_LIBS="-liconv"
    
            R -q -e "options(repos = \\"https://cloud.r-project.org\\") ; install.packages(\\"renv\\") ; options(renv.consent = TRUE, renv.config.install.staged=FALSE, renv.settings.use.cache=TRUE) ; install.packages(\\"BiocManager\\"); BiocManager::install(version=\\"3.9\\", ask=FALSE) ; renv::restore(lockfile = \\"${params.dragonDependencies}/r/renv.lock\\")"
            """
        } else {
            """
            echo "profiles: ${workflow.profile} ; skip renv step"
            """
        }
    }
    
    doneCh.set{ renvDoneCh }


This process allows the usage of the R software with the ``multiconda`` profile. During this process, the dependencies provided in the ``renv.lock`` will be installed.

.. warning::

   After the ``initRenv`` process, add the line ``doneCh.set{ renvDoneCh }``. The channel ``renvDoneCh`` will be an input for any process which will use the ``r`` label.


Copy you ``renv.lock`` file in ``recipes/dependencies/r``
=========================================================

We assume that the reader is familiar with `renv <https://rstudio.github.io/renv/>`_. Copy your ``renv.lock`` file in the folder ``recipes/dependencies/r``. Here is an example of a ``renv.lock`` file:

.. literalinclude:: ../data/recipes/dependencies/r/renv.lock


Write the docker recipe
=======================

Write the docker recipe in the file ``recipes/docker/r.Dockerfile`` as follows:

.. literalinclude:: ../data/recipes/docker/r.Dockerfile

Write the singularity recipe
============================

Write the singularity in the file ``recipes/singularity/r.def`` as follows:

.. literalinclude:: ../data/recipes/singularity/r.def


Add a process
=============

Write you process using the ``r`` label and always add as input ``val(done) from renvDoneCh``

::

   process testR {
       label 'r'
       label 'smallCpu'
       label 'memS'
   
       input:
       val(done) from renvDoneCh
   
       script:
       """
       R --version
       """
   }

