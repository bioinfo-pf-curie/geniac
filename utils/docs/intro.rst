.. _intro-page:

************
Introduction
************

The document provides guidelines to implement pipelines using the workflow manager `Nextflow <https://www.nextflow.io/>`_. We assume that the reader is familiar with `Nextflow <https://www.nextflow.io/>`_, if not, please refer to the documentation.


Explain why we decided to have one container per tool and not a big container with everyting (sometimes, this is not possible because you can have tools that are not compatible). Also, you can reuse your container between different pipelines if they use the same tool which allows a mutualisation.

.. note::

   Container are built using CentOS 7 distribution.


