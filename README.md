# Analysis pipeline 

[![Nextflow](https://img.shields.io/badge/nextflow-%E2%89%A519.10.0-brightgreen.svg)](https://www.nextflow.io/)
[![Install with](https://anaconda.org/anaconda/conda-build/badges/installer/conda.svg)](https://conda.anaconda.org/anaconda)
[![Singularity Container available](https://img.shields.io/badge/singularity-available-7E4C74.svg)](https://singularity.lbl.gov/)
[![Docker Container available](https://img.shields.io/badge/docker-available-003399.svg)](https://www.docker.com/)

### Introduction

The pipeline is built using [Nextflow](https://www.nextflow.io), a workflow tool to run tasks across multiple compute infrastructures in a very portable manner. 
It comes with conda / singularity containers making installation easier and results highly reproducible.

### Pipeline summary

Describe here the main steps of the pipeline.

1. Step 1 does...
2. Step 2 does...
3. etc

### Quick help

```bash
nextflow run main.nf --help
N E X T F L O W  ~  version 19.10.0
Launching `main.nf` [stupefied_darwin] - revision: aa905ab621
=======================================================

Usage:


Mandatory arguments:

Options:


=======================================================
Available Profiles

  -profile conda
  -profile multiconda
  -profile singularity
  -profile docker
  -profile path
  -profile cluster
		  
```

### Quick run

The pipeline can be run as described below.

#### Run the pipeline on the test dataset
See the conf/test.conf to set your test dataset.

```
run main.nf -c conf/test.config -profile multiconda

```

#### Run the pipeline from a sample plan

```
nextflow run main.nf --samplePlan mySamplePlan --genome 'hg19' --outputDir myOutputDir -profile multiconda

```

#### Run the pipeline on a computational cluster

A compléter

### Defining the '-profile'

A compléter

## Run the pipeline on the cluster, using the Singularity containers

A compléter

## Run the pipeline on the cluster, building a new conda environment
A compléter


### Sample Plan

A sample plan is a csv file (comma separated) that list all samples with their biological IDs.


Sample ID | Sample Name | Path R1 .fastq file | [Path R2 .fastq file]

### Full Documentation

A compléter/ modifier

1. [Installation](docs/installation.md)
2. [Reference genomes](docs/reference_genomes.md)
3. [Running the pipeline](docs/usage.md)
4. [Output and how to interpret the results](docs/output.md)
5. [Troubleshooting](docs/troubleshooting.md)

#### Credits

This pipeline has been written by the Institut Curie bioinformatics platform.

#### Contacts

For any question, bug or suggestion, please send an issue or contact the bioinformatics core facility.

