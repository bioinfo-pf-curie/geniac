# Installation

This documentation has been modified from the nf-core guidelines
(see https://nf-co.re/usage/installation for details).

To start using this pipeline, follow the steps below:

1. [Install Nextflow](#1-install-nextflow)
2. [Install the pipeline](#2-install-the-pipeline)
3. [Pipeline configuration](#3-pipeline-configuration)
    * [Cluster usage](#31cluster-usage)
    * [Software deps: Singularity](#31-software-deps-singularity)
    * [Software deps: Conda](#32-software-deps-conda)
    * [Software deps: Tools Path](#32-software-deps-tools-path)
4. [Reference genomes](#4-reference-genomes)

## 1) Install NextFlow
Nextflow runs on most POSIX systems (Linux, Mac OSX etc). It can be installed by running the following commands:

```bash
# Make sure that Java v8+ is installed:
java -version

# Install Nextflow
curl -fsSL get.nextflow.io | bash

# Add Nextflow binary to your PATH:
mv nextflow ~/bin/
# OR system-wide installation:
# sudo mv nextflow /usr/local/bin
```

See [nextflow.io](https://www.nextflow.io/) for further instructions on how to install and configure Nextflow.

## 2) Install the pipeline

### Basic installation

First, clone the repository using `git clone http://repository_url`

Note that the current repo contains a test dataset managed with `git lfs`.
Be sure that `git lfs` is instaled and run `git lfs pull` to pull the test datasets.

In order to run the pipeline out-of-the box, you will have to move the `*.config.example` files into `*.config` files, edit them and set the expected path compliant with your setup.


## 3) Pipeline configuration

By default, the pipeline loads a basic server configuration [`conf/base.config`](../conf/base.config)
This uses a number of sensible defaults for process requirements and is suitable for running
on a simple (if powerful!) local server.

Be warned of two important points about this default configuration:

1. The default profile uses the `local` executor
    * All jobs are run in the login session. If you're using a simple server, this may be fine. 
	If you're using a compute cluster, take care of not running all jobs on the head node.
    * See the [nextflow docs](https://www.nextflow.io/docs/latest/executor.html) for information about running with other hardware backends.
	Most job scheduler systems are natively supported.
2. Nextflow will expect all software to be installed and available on the `PATH`
    * It's expected to use an additional config profile for docker, singularity or conda support. See below.

#### 3.1) Cluster usage

In order to use the pipeline on a computational cluster, you will have to specify a few parameters.
Please, edit the `cluster.config` file to set up your own cluster configuration.

#### 3.2) Software deps: Singularity

Using [Singularity](http://singularity.lbl.gov/) is in general a great idea to manage environment and ensure reproducibility.
The process is very similar: running the pipeline with the option `-profile singularity` tells Nextflow to enable singularity for this run. 
Images containing all of the software requirements can be automatically fetched as explained in the folder [`utils/singularity`](../utils/singularity/README.md).
In addition the `containerPath` variable from the `containers.config` file has to be modified to set the path to the singularity images.

#### 3.3) Software deps: Conda

If you're not able to use Docker _or_ Singularity, you can instead use conda to manage the software requirements.
This is slower and less reproducible than the above, but is still better than having to install all requirements yourself!
The pipeline ships with a conda environment file and nextflow has built-in support for this.
To use it first ensure that you have conda installed (we recommend [miniconda](https://conda.io/miniconda.html)), then follow the same pattern as above and use the flag `-profile conda`
Note that in this case, the environment will be created in the `cache/work` folder.

### 3.4) Software deps: Tools Path

Finally, if for any reason you do not want to use conda or singularity, the pipeline provides a last config file `tools-path.config`
which allows to simply set the `PATH` environment from which all dependancies must be available.

## 4) Reference genomes

See [`docs/reference_genomes.md`](reference_genomes.md)
