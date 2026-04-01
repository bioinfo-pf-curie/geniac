#!/usr/bin/env bash

# Generate full conda env recipes from the minimal env file (conda dependencies) 
# and the pyproject.toml (pip dependencies)

rand=$RANDOM

# simulate conda init
eval "$(conda shell.bash hook)"

conda env create -n geniac_$rand -f environment_minimal.yml 

conda activate geniac_$rand
yes | pip install . 

# remove geniac tools in the recipes
conda env export | grep -v "\- geniac" | grep -v -E "^prefix" > environment.yml

sed -i "s/geniac_$rand/geniac/g" environment.yml
conda deactivate

conda env remove -n geniac_$rand -y


