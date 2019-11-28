# To internal install the RNA-seq pipeline tools with Docker

Docker is a great way to run nextflow pipelines, as it allows the pipelines to be run in an identical software environment across a range of systems.
If you intend to run the pipeline offline, nextflow will not be able to automatically download the docker image for you. Instead, you'll have to do this yourself manually first, transfer the image file and then point to that. The docker profile provides a configuration profile for docker, making it very easy to use.
This document is here to help you do this internal installation.

### Installation  summary

1. First, install docker on your system: https://docs.docker.com/engine/installation/.


2. Run the script to build the containers for all tools
   default creation of docker containers in the current directory ./images/, for example if you run the script under : /your_internal_path/containers/docker/rnaseq-2.0/images/
```
    Example: bash build_containers.sh 2>&1 | tee -a build_containers.log
```
3. Edit the containers configuration: containers.config

```bash

    params {
      container_version = '2.0'
     containerPath = "file:///your_internal_path/containers/docker/rnaseq-2.0/images"
    .
    .
    .
    }
```
### Quick run
Run the pipeline locally, using the your internal global environment and tools build docker.
Running the pipeline with the option -profile docker tells Nextflow to enable Docker for this run.

```
nextflow run main.nf -profile test,docker

```

