# To internal install the RNA-seq pipeline tools with conda 

### Installation  summary

1. Conda installation : To use it first ensure that you have conda installed (we recommend miniconda).


2. Run the script to build the tools
```
    Example: bash install_tools_via_conda.sh /your_path/tools
```
3. Adding your own configuration profile: copy the curie profile into your profile
```
    Example: cp conf/curie.config conf/internal.config
```

4. Edit your new internal profile: change the path of your local installation

```bash
    singularity {
     enabled = false 
    }

    process {
      beforeScript = 'export PATH=/your_path/tools/rnaseq-2.0/bin:$PATH'
    }
```

1. Edit the main configuration file: nextflow.config

```bash

    // Profiles
    profiles {
     conda { process.conda = "$baseDir/environment.yml" }
     docker { docker.enabled = true }
     singularity { 
       includeConfig 'conf/singularity.config'
      }
      internal {
        includeConfig 'conf/internal.config'
      }
      test {
       includeConfig 'conf/test.config'
      }
      cluster {
       includeConfig 'conf/cluster.config'
      }
    }

```

   



### Quick run
Run the pipeline locally, using the your internal global environment and tools build by conda

```
nextflow run main.nf -profile test,internal

```


