# Reference Genomes Configuration

The pipeline needs a reference genome for alignment and annotation.
All annotation data and paths must be defined/modified in the `conf/genomes.conf` files.

These paths can be supplied on the command line at run time (see the [usage docs](../usage.md)),
but for convenience it's often better to save these paths in a nextflow config file.
See below for instructions on how to do this.

## Adding paths to a config file
Specifying long paths every time you run the pipeline is a pain.
To make this easier, the pipeline comes configured to understand reference genome keywords which correspond
to preconfigured paths, meaning that you can just specify `--genome ID` when running the pipeline.

Note that this genome key must be specified in the config file `genomes.conf`.

To use this system, add paths to your config file using the following template:

```nextflow
params {
  genomes {
    'YOUR-ID' {
      fasta  = '<PATH TO FASTA FILE>/genome.fa'
    }
    'OTHER-GENOME' {
      // [..]
    }
  }
  // Optional - default genome. Ignored if --genome 'OTHER-GENOME' specified on command line
  genome = 'YOUR-ID'
}
```

You can add as many genomes as you like as long as they have unique IDs.

## illumina genomes
To make the use of reference genomes easier, illumina has developed a centralised resource called [genomes](https://support.illumina.com/sequencing/sequencing_software/igenome.html).
Multiple reference index types are held together with consistent structure for multiple genomes.

We have put a copy of genomes up onto AWS S3 hosting and this pipeline is configured to use this by default.
The hosting fees for AWS genomes are currently kindly funded by a grant from Amazon.
The pipeline will automatically download the required reference files when you run the pipeline.
For more information about the AWS genomes, see https://ewels.github.io/AWS-genomes/

Downloading the files takes time and bandwidth, so we recommend making a local copy of the genomes resource.
Once downloaded, you can customise the variable `params.genomes_base` in your custom configuration file to point to the reference location.

```nextflow
params.genomes_base = '/path/to/data/genomes/'
```


