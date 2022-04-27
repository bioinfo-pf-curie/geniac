.. include:: substitutions.rst

.. _intro-page:

************
Introduction
************

Context
=======

The document provides guidelines to implement pipelines using the workflow manager |nextflow|_. We assume that the reader is familiar with |nextflow|_, if not, please refer to the documentation. We capitalized on the |nfcore|_ project by providing additional utilities and guidelines for production-ready bioinformatics pipelines.

We propose a set of best practices along the development life cycle of the pipeline and deployment for production operations that address different expert communities:

* the bioinformaticians and statisticians who will prototype the pipeline with state-of-the-art methods in order to extract most of the hidden value from the data and provide summary reports for end-users,
* the software engineers who will optimize the pipeline to reduce the amount of informatic resources required, to shorten the time to result delivery, to allow its scalabitity, portability and reproducibility,
* the data managers and core facility engineers who will deploy and operate the pipeline in daily production for the end-users.

The utilities and guidelines were motivated by:

* being as less as invasive on the different expert communities,
* reducing the overall development cycle from the prototyping stage to the deployment in a production environment,
* providing portable pipelines with containers (|docker|_, |podman|_ and |singularity|_),
* automating (whenever possible) the building of containers from the source code of the pipeline.

Offering the portability of the pipeline with containers can be achieved in two ways:

#. either a single container including all the tools required by the pipeline is provided,
#. or several containers (one container for each tool) are provided. 

We decided to retain this second way that we will call the *one container per tool* strategy   for the following reasons:

* most of the pipelines share tools in common meaning that, once a container is built for one tool, it can be easily reused in other pipelines,

* sometimes, different tools that might be incompatible with each other are required and that just makes impossible to build a single container including all the tools for the pipeline,

* building a container with all the tools can be very long and possibly tedious especially when there is a single container. Each time the pipeline changes, the single container has to be rebuilt. With the *one container per tool* strategy, you only have to update the container whose tool has changed (that is faster),
  
* you can also parallelize the building of the containers such that it reduces the time to have the containers available.

With this *one container per tool* strategy in mind, we therefore defined guidelines to implement the pipeline at the very early stage of the prototyping with very few effort from the bioinformaticians and statisticians such that the containers can be automatically built by parsing the source code (in most of the cases).

To do so, we expect that the bioinformaticians and statisticians capitalize on the software that are available from the |conda|_ channels whenever possible. 

All the guidelines are detailed in the next sections.

Resources
=========

Useful resources for geniac are available here:

* |geniacdoc|_
* |geniacrepo|_
* |geniacdemo|_
* |geniacdemodsl2|_
* |geniactemplate|_
* |4geniac|_ docker hub repository with the :ref:`linux-page`
* Example: :download:`useCases.bash <../data/useCases.bash>`


Acknowledgements
================

* `Institut Curie <https://www.curie.fr>`_
* `Centre national de la recherche scientifique <https://www.cnrs.fr>`_
* This project has received funding from the European Union’s Horizon 2020 research and innovation programme and the Canadian Institutes of Health Research under the grant agreement No 825835 in the framework on the `European-Canadian Cancer Network <https://eucancan.com/>`_.

Citation
========

|geniacref|_
