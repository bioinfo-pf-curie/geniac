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
        - r-base=4.1.3=h06d3f91_1


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

This process allows the usage of the R software with the ``multiconda`` and ``conda`` profiles. During this process, the dependencies provided in the ``renv.lock`` will be installed.

In your ``main.nf``, add the following process:

::

    process renvGladInit {
      label 'onlyLinux'
      label 'minCpu'
      label 'minMem'
    
      output:
      val(true) into renvGladInitDoneCh
    
      script:
        def renvName = 'renvGlad' // This is the only variable which needs to be modified
        def renvYml = params.geniac.tools.get(renvName).get('yml')
        def renvEnv = params.geniac.tools.get(renvName).get('env')
        def renvBioc = params.geniac.tools.get(renvName).get('bioc')
        def renvLockfile = projectDir.toString() + '/recipes/dependencies/' + renvName + '/renv.lock'
        
    
        // The code below is generic, normally, no modification is required
        if (workflow.profile.contains('multiconda') || workflow.profile.contains('conda')) {
            """
            if conda env list | grep -wq ${renvEnv} || [ -d "${params.condaCacheDir}" -a -d "${renvEnv}" ] ; then
                echo "prefix already exists, skipping environment creation"
            else
                CONDA_PKGS_DIRS=. conda env create --prefix ${renvEnv} --file ${renvYml}
            fi
      
            set +u
            conda_base=\$(dirname \$(which conda))
            if [ -f \$conda_ conda/../../etc/profile.d/conda.sh ]; then
              conda_script="\$conda_base/../../etc/profile.d/conda.sh"
            else
              conda_script="\$conda_base/../etc/profile.d/conda.sh"
            fi
      
            echo \$conda_script
            source \$conda_script
            conda activate ${renvEnv}
            set -u
      
            export PKG_CONFIG_PATH=\$(dirname \$(which conda))/../lib/pkgconfig
            export PKG_LIBS="-liconv"
      
            R -q -e "options(repos = \\"https://cloud.r-project.org\\") ; install.packages(\\"renv\\") ; options(renv.consent = TRUE, renv.config.install.staged=FALSE, renv.settings.use.cache=TRUE) ; install.packages(\\"BiocManager\\"); BiocManager::install(version=\\"${renvBioc}\\", ask=FALSE) ; renv::restore(lockfile = \\"${renvLockfile}\\")"
            """
        } else {
            """
            echo "profiles: ${workflow.profile} ; skip renv step"
            """
        }
    }
    
    renvGladInitDoneCh.set{ renvGladDoneCh}


.. important::

    The name of the process must start by the label of the tool followed by the ``Init`` suffix, for example ``renvGladInit``.

    This process must use the label ``onlyLinux`` (see :ref:`process-unix`).

    In the ``output`` section, define a channel with the name of the label followed by the ``InitDoneCh`` suffixe, for example ``val(true) into renvGladInitDoneCh``.

    After the process, define a channel to indicate that the ``renv`` has been initiated. The channel must start by the name of the label followd by the ``DoneCh`` suffixe, for example ``renvGladInitDoneCh.set{ renvGladDoneCh}``

    In this process, set the content of the variable ``renvName`` to the label of the tool, for axample ``renvGlad``.


Copy you ``renv.lock`` file  is a sublder inside ``recipes/dependencies/``
==========================================================================

We assume that the reader is familiar with `renv <https://rstudio.github.io/renv/>`_. In the folder ``recipes/dependencies/``, create a subfolder with the name of the label of the tool, for example ``recipes/dependencies/renvGald``. Then, copy your ``renv.lock`` file in this subfolder . Here is an example of a ``renv.lock`` file:

.. literalinclude:: ../data/recipes/dependencies/renvGlad/renv.lock



Add a process which uses the renv
=================================

Write you process using the label with the ``renv`` tool and always define in the ``input`` section of the process the channel that has been previously set, for example ``val(done) from renvGladDoneCh``

::

    process glad {
      label 'renvGlad'
      label 'minCpu'
      label 'minMem'
      publishDir "${params.outDir}/GLAD", mode: 'copy'
    
      input:
      val(done) from renvGladDoneCh
    
      output: 
      file "BkpInfo.tsv"
    
      script:
      """
      Rscript ${projectDir}/bin/apGlad.R
      """
    }
