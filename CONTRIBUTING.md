# Documentation

Principle: one process = one software

## Add a software in the pipeline

### The software is available in conda

* edit `pipeline/conf/template/base.in.config`

* in the section `params.tools` add  `rmarkdown = "conda-forge::r-markdown=0.8"` as follows:


```
params {
    tools {
        rmarkdown = "conda-forge::r-markdown=0.8"
        soft2 = "condaChannelName::softName=version"
    }
}
```

Then add the process in the `main.nf`, the process can take any name but as to refer to the software with the `label` directive with the exact same name as given in the `params.tools` section:

```
process output_documentation {
    label 'rmarkdown'
    publishDir "${params.outdir}/pipeline_info", mode: 'copy'

    input:
    file output_docs from ch_output_docs

    output:
    file "results_description.html"

    script:
    """
    markdown_to_html.r $output_docs results_description.html
    """
}
```

This way, the software `rmarkdown` can be used in any other process provided that the `label` directive is used:

```
process something_else_with_rmarkdown {
    label 'rmarkdown'
    publishDir "${params.outdir}/pipeline_info", mode: 'copy'

    script:
    """
    some_rmarkdown_script.r
    """
}
```

Note that if needed, some conda dependencies can be added when the software is specified, for example the `fastqc` software:




params {
 
  tools {
    fastqc = "conda-forge::openjdk=8.0.192=h14c3975_1003 bioconda::fastqc=0.11.6=2"
  }
}

Note that the name of the software provided in `params.tools` can be anyname (is it not necessarly the same nane as the software will be called in command line).


* edit the file `pipeline/conf/multiconda.config` and add

```
process {
    withLabel: rmarkdown { conda = params.tools.rmarkdown}
 
}
```


* edit the file `pipeline/conf/singularity.config` and add

TO BE COMPLETED





### The software is available in conda but a tricky yml recipe is needed
