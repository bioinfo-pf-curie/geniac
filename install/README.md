# Content of the install folder

Geniac launches a nextflow pipeline which generates config files, container recipes and build/push the containers. The nextflow pipeline is in this folder which contains the following files:


```
├── lib
│   └── functions.nf
├── main.nf
├── nextflow.config.in
├── nf-modules
   └── local
       ├── process
       │   ├── dockerImages.nf
       │   ├── pushDockerImages.nf
       │   └── singularityImages.nf
       └── subworkflow
           ├── configFilesWkfl.nf
           ├── dockerRecipesWkfl.nf
           └── singularityRecipesWkfl.nf
```

Note that the `nextflow.config.in` has the `.in` as it contains placeholder variables such as `@linux_distro@`. These variables will be replaced by their correct values during the `cmake` configuration step which will rename the file into `nextflow.config`. Therefore, `nextflow.config.in` is the template for the final file which will be used when running nextflow.

