
process renvInit {
  label 'onlyLinux'
  label 'minCpu'
  label 'minMem'

  input:
    val renvName

  output:
    val renvInitDone, emit: renvInitDone

  script:
    def renvYml = params.geniac.tools.get(renvName).get('yml')
    def renvEnv = params.geniac.tools.get(renvName).get('env')
    def renvBioc = params.geniac.tools.get(renvName).get('bioc')
    def renvLockfile = projectDir.toString() + '/recipes/dependencies/' + renvName + '/renv.lock'
    

    // The code below is generic, normally, no modification is required
    if (workflow.profile.contains('multiconda') || workflow.profile.contains('conda')) {
        renvInitDone = "Conda will be created if it does not exist"
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
        renvInitDone = "Conda env not needed"
        """
        echo "profiles: ${workflow.profile} ; skip renv step"
        """
    }
}
