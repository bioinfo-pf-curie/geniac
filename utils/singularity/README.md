# To internal install the RNA-seq pipeline tools with Singularity 

Many HPC environments are not able to run Docker due to security issues. Singularity is a tool designed to run on such HPC systems which is very similar to Docker.
If you intend to run the pipeline offline, nextflow will not be able to automatically download the singularity image for you. Instead, you'll have to do this yourself manually first, transfer the image file and then point to that. The singularity profile provides a configuration profile for singumlarity, making it very easy to use.
This document is here to help you do this internal installation.

### Installation  summary

1. Singularity installation : To use it first ensure that you have singularity installed.


2. Run the script to build the containers for all tools
   default creation of singularity containers in the current directory ./images/, for example if you run the script under : /your_internal_path/containers/singularity/rnaseq-2.0/images/
```
    Example: bash build_containers.sh 2>&1 | tee -a build_containers.log
```
3. Edit the containers configuration: containers.config

```bash

    params {
      container_version = '2.0'
     containerPath = "file:///your_internal_path/containers/singularity/rnaseq-2.0/images"
    .
    .
    .
    }
```
### Quick run
Run the pipeline locally, using the your internal global environment and tools build singularity.
Running the pipeline with the option -profile singularity tells Nextflow to enable Singularity for this run.

```
nextflow run main.nf -profile test,singularity

```

