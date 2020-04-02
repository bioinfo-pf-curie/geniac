# Installation guidelines


**WARNING this document in WIP mode**


## Build and install singularity images


* either edit `geniac/install/cmake-init.cmake` and check that you have `set(ap_install_singularity_images "ON" CACHE BOOL "")`
* or invoke `cmake` with the option `-Dap_install_singularity_images=ON`

* to build singularity images, root credentials are required
	* either type `make` if you have `fakeroot` singularity credentials
	* or `sudo make` if you have sudo privileges
	
* then `make install`

If you want to build the recipes without installing them type  `make build_singularity_recipes`. Recipes will be generated in `build/containerWorkdir/deffiles`.

If you want to build the images without installing them type `make build_singularity_images`. Images will be generated in  `build/containerWorkdir/singularityImages`.

We also provide a `cmake` interface to build the configuration files and install the pipeline according to your needs as described below.

### Advanced installation

Check that `cmake` with  `version 3` is installed on you computer.
In some distributions (such as CentOS) it is available with the command `cmake3`

#### Installation steps

* Let's assume you have cloned the git repository in the folder `${HOME}/RNA-seq`

* Create the folder `${HOME}/build`

* `cd ${HOME}/build`

#### Display the options available for installation

The different options are displayed using the following command in the **Cache values** section:

* `cmake -LH ../RNA-seq/`

The options for the **a**nalysis **p**ipeline start with the prefix **ap**


#### Set the option for the installation

Default options have to be replaced. Otherwise, the pipeline will not work.

* `cmake ../RNA-seq -DCMAKE_INSTALL_PREFIX=${HOME}/install -Dap_singularity_image_path=/path/to/images -Dap_annotation_path=/data/annotations/pipelines`

Other options can be provided.

* Altenatively, you can use  `cmake  -C ../RNA-seq/install/cmake-init.cmake ../RNA-seq/` provided that you first edited the
`../RNA-seq/install/cmake-init.cmake` to set the options complant with your setup.

#### Installation

* `make; make install`

The pipeline will be available in `${HOME}/install` (i.e. in the path you defined using `-DCMAKE_INSTALL_PREFIX`). 
The config files with the defined options will be available in the `conf` folder of your installed version.

### For developpers

To avoid multiple installations for testing while developping, the developpers can copy the content of `${HOME}/install/conf`
to `${HOME}/RNA-seq/conf` and run the pipeline as usually.
