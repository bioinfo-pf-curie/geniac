.. _intro-page:

************
Introduction
************

The document provides guidelines to implement pipelines using the workflow manager `Nextflow <https://www.nextflow.io/>`_. We assume that the reader is familiar with `Nextflow <https://www.nextflow.io/>`_, if not, please refer to the documentation. We capitalized on the `nf-core <https://nf-co.re/>`_ project by providing additional utilities and guidelines for production-ready bioinformatics pipelines.

We propose a set of best practises along the development life cycle of the pipeline and deployement for production operations that address different expert communities:

* the bioinformaticians and statisticians experts in the fields of analysis who will prototype the pipeline with state-of-the-art methods in order to extract most of the hidden value from the data and provide summary reports for end-users,
* the software engineers who will optimize the pipeline to reduce the amount of informatic resources required, to shorten the time to result delivery, to allow its scalabitity, portability and reproducibility,
* the data managers and core facility engineers who will deploy and operate the pipeline in daily production for the end-users.

The utilies and guidelines were motivated by:

* being as less as invasive on the different expert communities,
* reducing the overall development cycle from the prototyping stage to the deployement in a production environment,
* providing portable pipelines with containers (`docker <https://www.docker.com>`_ and `singularity <https://sylabs.io/docs/#singularity>`_),
* automazing (whenever possible) the building of containers from the source code of the pipeline.

Offering the portability of the pipeline with containers can be achieved in two ways. Either a single container including all the tools required by the pipeline is provided or several containers (one container for each tool) are provided. We decided to retain this second way that we will call the *one container per tool* strategy   for the following reasons:

* most of the pipelines share tools in common meaning that, once a container is built for one tool, it can be easily reused in other pipelines,

* sometimes, different tools that migth be incompatible with each other are required and that just makes impossible to build a single container including all the tools for the pipeline,

* building a container with all the tools can be very long and possibly tedious especially when there is a single container. Each time the pipeline changes, the single container has to be rebuilt. With the *one container per tool* strategy, you only have to update the container whose tool has changed (that is faster). Moreover, you can also parallelise the building of the containers such that it reduces the time to have the containers available, 

With this *one container per tool* strategy in mind, we therefore defined guidelines to implement the pipeline at the very early stage of the prototyping with very few effort from the bioinformaticians and statisticians experts such that the containers can be automatically built by parsing the source code (in most of the cases).

To do so, we expect that the bioinformaticians and statisticians capitalize on the software that are available from the `conda <https://docs.conda.io>`_ channels whenever possible. 

All the guidelines are detailed in the next sections.


