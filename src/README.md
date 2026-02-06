## Content of the src folder

Geniac comes with a command line interface (CLI) including:

```
geniac clean
geniac configs
geniac init
geniac install
geniac lint
geniac options
geniac recipes
geniac test
```

They have been written in python. This folder contains the source code for the python package:

- `src/geniac/cli/commands`: it contains a file for each geniac command and the base class to launch any geniac command.
- `src/geniac/cli/data/conf`: it contains the file `geniac.ini` and `logging.json` which define the default behaviour `geniac lint` and the format for the log information.
- `src/geniac/cli/parsers`: it contains the scripts to read the source code of the nextflow pipeline to install including `.config` and `.nf` files.
- `src/geniac/cli/utils`: it contains functions to check the compliance of the nextflow pipeline with geniac best pratices

In addition to this files there is the file `setup.cfg` located in the root directory of the geniac source code which make it possible to install geniac, for example using `pip install -U`.


