## New feature

Update the 4geniac DockerHub registry with {linuxDistro} and miniforge {condaRelease}

## Use case

When building containers, geniac first write recipes which boostrap docker container available on the `4geniac` DockerHub registry  (https://hub.docker.com/u/4geniac).

The source code to build new container versions is here: https://github.com/bioinfo-pf-curie/4geniac 

## Suggested implementation

TODO:
- [ ] Update the GitHub repo https://github.com/bioinfo-pf-curie/4geniac
- [ ] Build the containers locally
- [ ] Push the containers on DockerHub
- [ ] Copy the containers on our GitLab registry
- [ ] Update the variable `ap_linux_distro` in the file cmake/stepSetVariables.cmake
- [ ] Update the variable `ap_conda_release` in the file cmake/stepSetVariables.cmake
- [ ] Update the doc with the default value for the parameters `ap_linux_distro` and `ap_conda_release`
- [ ] Launch all the tests

/label ~enhancement
