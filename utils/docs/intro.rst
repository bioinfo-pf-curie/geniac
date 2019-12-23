.. _intro-page:

************
Introduction
************

The document provides guidelines to implement pipelines using the workflow manager `Nextflow <https://www.nextflow.io/>`_. We assume that the reader is familiar with `Nextflow <https://www.nextflow.io/>`_, if not, please refer to the documentation. We capitalized on the `nf-core <https://nf-co.re/>`_ project by providing additional utilities and guidelines for production-ready bioinformatics pipelines.

Here, we proposed a set of best practises that address different expertise communities along the development life cycle of the pipeline and deployement for production operations:

* the bioinformaticians and statisticians expertis in the fields of analysis who will prototype the pipeline with state-of-the-art methods in order to extract most of the hidden value from the data and provide summary reports for end-users,
* the software engineers who will optimize the pipeline to reduce the amount of informatic resources required, to shorten the time to delivery, to allow its scalabitity, portability and reproducibility,
* the data managers and core facility engineers who will deploy and operate the pipeline in daily production for the end-users.


Motivations
===========

We decided to have one container per tool rather than having a single  container (including all the tools) for each pipeline  for the following reasons:

* most of the pipelines share tools in common meaning that, once a container is built for one tool, it can be easily reused,

* sometimes, it turns out that you need different tools that migth be incompatible with each other that just makes impossible to build a single unique container with all you need for the pipeline,

* building a container with all the tools can be very long and possibly tedious. Each time the pipeline changes, the container has to be rebuilt. With the *one container per tool* strategy, you only have to update the container whose tool has changed (that is faster). Moreover, you can also parallelise the building of the containers such that it reduces the time to have your containers, 

With this *one container per tool* strategy in mind, we therefore defined guidelines to implement the pipeline at the very early stage of the prototyping with very few effort from the bioinformaticians and statisticians experts such that the containers can be automatically built by parsing the source code (in most of the cases).

To do so, we expect that the bioinformaticians and statisticians capitalize on the software that are available from the `conda <https://docs.conda.io>`_ channels whenever possible.



.. note::

   The containers are boostraped using `CentOS <https://www.centos.org/>`_ 7 distribution.


