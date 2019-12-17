# RNA-seq 

**Institut Curie - Nextflow rna-seq analysis pipeline**

[![Nextflow](https://img.shields.io/badge/nextflow-%E2%89%A50.32.0-brightgreen.svg)](https://www.nextflow.io/)
[![MultiQC](https://img.shields.io/badge/MultiQC-1.7-blue.svg)](https://multiqc.info/)
[![Install with](https://anaconda.org/anaconda/conda-build/badges/installer/conda.svg)](https://conda.anaconda.org/anaconda)
[![Singularity Container available](https://img.shields.io/badge/singularity-available-7E4C74.svg)](https://singularity.lbl.gov/)
<!--[![Docker Container available](https://img.shields.io/badge/docker-available-003399.svg)](https://www.docker.com/)-->

### Introduction

The pipeline is built using [Nextflow](https://www.nextflow.io), a workflow tool to run tasks across multiple compute infrastructures in a very portable manner. 
It comes with conda / singularity containers making installation easier and results highly reproducible.

The first version of this pipeline was modified from the [nf-core/rnaseq](https://github.com/nf-core/rnaseq) pipeline. 
See the [nf-core](https://nf-co.re/) project for more details.

### Pipline summary

1. Run quality control of raw sequencing reads ([`fastqc`](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/))
2. Align reads on ribosomal RNAs sequences when available ([`bowtie1`](http://bowtie-bio.sourceforge.net/index.shtml))
3. Align reads on reference genome ([`STAR`](https://github.com/alexdobin/STAR) / [`tophat2`](http://ccb.jhu.edu/software/tophat/index.shtml) / [`hisat2`](http://ccb.jhu.edu/software/hisat2/index.shtml))
4. Infer reads orientation ([`rseqc`](http://rseqc.sourceforge.net/))
5. Dedicated quality controls
    - Saturation curves ([`preseq`](http://smithlabresearch.org/software/preseq/) / [`R`](https://www.r-project.org/))
    - Duplicates ([`picard`](https://broadinstitute.github.io/picard/) / [`dupRadar`](https://bioconductor.org/packages/release/bioc/html/dupRadar.html))
    - Reads annotation ([`rseqc`](http://rseqc.sourceforge.net/) / [`R`](https://www.r-project.org/))
    - Gene body coverage ([`rseqc`](http://rseqc.sourceforge.net/))
6. Generate counts table ([`STAR`](https://github.com/alexdobin/STAR) / [`featureCounts`](http://bioinf.wehi.edu.au/featureCounts/) / [`HTSeqCounts`](https://htseq.readthedocs.io/en/release_0.11.1/count.html))
7. Exploratory analysis ([`R`](https://www.r-project.org/))
8. Present all QC results in a final report ([`MultiQC`](http://multiqc.info/))

### Quick help

```bash
nextflow run main.nf --help
N E X T F L O W  ~  version 19.04.0
Launching `main.nf` [stupefied_darwin] - revision: aa905ab621
rnaseq v2.0.0dev
=======================================================

Usage:
nextflow run rnaseq --reads '*_R{1,2}.fastq.gz' --genome 'hg19' 

Mandatory arguments:
  --reads                       Path to input data (must be surrounded with quotes)
  --samplePlan                  Path to sample plan input file (cannot be used with --reads)
  --genome                      Name of genome reference
  -profile                      Configuration profile to use. test / conda / toolsPath / singularity / cluster

Options:
  --singleEnd                   Specifies that the input is single end reads

Strandedness:
  --stranded                    Library strandness ['auto', 'forward', 'reverse', 'no']. Default: 'auto'

Mapping:
  --aligner                     Tool for read alignments ['star', 'hisat2', 'tophat2']. Default: 'star'

Counts:
  --counts                      Tool to use to estimate the raw counts per gene ['star', 'featureCounts', 'HTseqCounts']. Default: 'star'

References:                     If not specified in the configuration file or you wish to overwrite any of the references.
  --star_index                  Path to STAR index
  --hisat2_index                Path to HiSAT2 index
  --tophat2_index	        Path to TopHat2 index
  --gtf                         Path to GTF file
  --bed12                       Path to gene bed12 file
  --saveAlignedIntermediates    Save the BAM files from the Aligment step  - not done by default

Other options:
  --metadata                    Add metadata file for multiQC report
  --outputDir                      The output directory where the results will be saved
  -w/--work-dir                 The temporary directory where intermediate data will be saved
  --email                       Set this parameter to your e-mail address to get a summary e-mail with details of the run sent to you when the workflow exits
  -name                         Name for the pipeline run. If not specified, Nextflow will automatically generate a random mnemonic.

QC options:
  --skip_qc                     Skip all QC steps apart from MultiQC
  --skip_rrna                   Skip rRNA mapping
  --skip_fastqc                 Skip FastQC
  --skip_genebody_coverage      Skip calculating genebody coverage 
  --skip_saturation             Skip Saturation qc
  --skip_dupradar               Skip dupRadar (and Picard MarkDups)
  --skip_readdist               Skip read distribution steps
  --skip_expan                  Skip exploratory analysis
  --skip_multiqc                Skip MultiQC

=======================================================
Available Profiles

  -profile test                Set up the test dataset
  -profile conda               Build a new conda environment before running the pipeline
  -profile toolsPath           Use the paths defined in configuration for each tool
  -profile singularity         Use the Singularity images for each process
  -profile cluster             Run the workflow on the cluster, instead of locally
		  
```

### Quick run

The pipeline can be run on any infrastructure from a list of input files or from a sample plan as follow

#### Run the pipeline on a test dataset
See the conf/test.conf to set your test dataset.

```
nextflow run main.nf -profile test,conda

```

#### Run the pipeline from a sample plan

```
nextflow run main.nf --samplePlan MY_SAMPLE_PLAN --genome 'hg19' --outputDir MY_OUTPUT_DIR -profile conda

```

#### Run the pipeline on a computational cluster

```
echo "nextflow run main.nf --reads '*.R{1,2}.fastq.gz' --genome 'hg19' --outputDir MY_OUTPUT_DIR -profile singularity,cluster" | qsub -N rnaseq-2.0

```

### Defining the '-profile'

By default (whithout any profile), Nextflow will excute the pipeline locally, expecting that all tools are available from your `PATH` variable.

In addition, we set up a few profiles that should allow you i/ to use containers instead of local installation, ii/ to run the pipeline on a cluster instead of on a local architecture.
The description of each profile is available on the help message (see above).

Here are a few examples of how to set the profile option.

```
## Run the pipeline locally, using the paths defined in the configuration for each tool (see conf.tool-path.config)
-profile toolsPath

## Run the pipeline on the cluster, using the Singularity containers
-profile cluster,singularity

## Run the pipeline on the cluster, building a new conda environment
-profile cluster,conda

```

### Sample Plan

A sample plan is a csv file (comma separated) that list all samples with their biological IDs.


Sample ID | Sample Name | Path R1 .fastq file | [Path R2 .fastq file]

### Full Documentation

1. [Installation](docs/installation.md)
2. [Reference genomes](docs/reference_genomes.md)
3. [Running the pipeline](docs/usage.md)
4. [Output and how to interpret the results](docs/output.md)
5. [Troubleshooting](docs/troubleshooting.md)

#### Credits

This pipeline has been written by the bioinformatics platform of the Institut Curie (P. La Rosa, N. Servant)

#### Contacts

For any question, bug or suggestion, please use the issues system or contact the bioinformatics core facility.

