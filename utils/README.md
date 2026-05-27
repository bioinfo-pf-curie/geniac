# How to update the geniac conda environment?

For ease of use, Geniac can be installed using a dependency management system based on **Conda** and **pip**. For reproducibility purpose, the conda recipe is provided in the main directory of the geniac repository within the file `environment.yml` which includes the exhaustive list of **Conda** and **pip** packages. This file must be generated automatically as described below.


## Modify pip dependencies

Edit the `pyproject.toml` file to add/remove/modify pip dependencies, for example:

```
[project]
dependencies = [
    "pyyaml==6.0.2",
    "setuptools-scm==8.1.0",
]
```

## Modify conda dependencies

Edit the `utils/environment_minimal.yml` file to add/remove/modify conda dependencies, for example:

```
name: geniac
channels:
  - conda-forge
  - bioconda
  - nodefaults
dependencies:
  - certifi=2024.7.4=pyhd8ed1ab_0
  - git=2.46.0=pl5321hb5640b7_0
  - git-lfs=3.5.1=h647637d_1
  - make=4.4.1=hb9d3cd8_2
  - nextflow=24.04.4=hdfd78af_0
```

The `utils/environment_minimal.yml` lists only the dependencies we know that they will be used by geniac. In contrast, the `environment.yml` lists all the package which are installed within the conda environment.


## Update the `environment.yml` file

After modifying any dependencies (pip or conda), **regenerate** the global `environment.yml` file by running the following script:

```bash
bash gen_env.sh
```

## What does the `gen_env.sh` script?

1. Creates a temporary environment with conda dependencies (`environment_minimal.yml`).
2. Installs pip dependencies from `pyproject.toml`.
3. Exports the complete environment to `environment.yml`.
4. Removes the temporary environment.


## Important Notes

- **Never edit** the `environment.yml` file directly: it is automatically generated.
- **Always check** for version conflicts after regeneration.

