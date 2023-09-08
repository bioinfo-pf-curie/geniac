.. include:: substitutions.rst

.. _from-source-examples-page:

****************************************
Install tools from source: more examples
****************************************

Installation from source code offers a great flexibility as the software developer can control everything during the installation process. However, this obviously requires more configuration. In particular, the software developer has to be fluent with |cmake|_ in order to tackle specific use cases. We provide in this section additional examples to :ref:`process-source-code`: they are available in the |geniacdemo|_ in the folder ``test/misc``. To run these examples, do the following:


::

   export WORK_DIR="${HOME}/tmp/myPipeline"
   export SRC_DIR="${WORK_DIR}/src"
   export INSTALL_DIR="${WORK_DIR}/install"
   export BUILD_DIR="${WORK_DIR}/build"
   export GIT_URL="https://github.com/bioinfo-pf-curie/geniac-demo.git"

   mkdir -p ${INSTALL_DIR} ${BUILD_DIR}



   # clone the repository
   # the option --recursive is needed if you use geniac as a submodule
   # the option --remote-submodules will pull the last geniac version
   # using the release branch from https://github.com/bioinfo-pf-curie/geniac 
   git clone --remote-submodules --recursive ${GIT_URL} ${SRC_DIR}

   # copy miscellaneous examples "Install from Source"
   for misc_file in $(find ${SRC_DIR}/test/misc/ -name "*nf.misc"); do mv ${misc_file} ${misc_file%%.misc} ;done
   rsync -avh --progress ${SRC_DIR}/test/misc/* ${SRC_DIR}
   rm -rf  ${SRC_DIR}/test/misc

   cd ${BUILD_DIR}

   # configure the pipeline
   cmake ${SRC_DIR}/geniac -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}

   # build the files needed by the pipeline
   make

   # install the pipeline
   make install


Move the tool binary in the expected folder
===========================================

You can retrieve a code which installs the tool not directly in the folder passed to the ``-DCMAKE_INSTALL_PREFIX`` argument but inside a subfolder. This is the case with the tool ``fastqpair``. This tool is provided with a ``CMakeLists.txt`` which installs the binary ``fastq_pair`` in the subfolder ``bin``. Therefore, you have to move the binary one level up otherwise, it will not be found in the ``PATH`` when using the :ref:`run-profile-conda` or :ref:`run-profile-multiconda` profiles. To do so, add in the file :download:`modules/fromSource/CMakeLists.txt <../data/modules/fromSource/CMakeLists.txt>` the ``ExternalProject_Add_Step`` directive in addition to the usual expected |cmakeexternalproject|_  function  such that you have for  ``fastqpair`` the following:

::

   ExternalProject_Add(
       fastq-pair
       SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/fastqpair
       CMAKE_ARGS
       -DCMAKE_INSTALL_PREFIX=${CMAKE_BINARY_DIR}/externalProject/bin)
   
   ExternalProject_Add_Step(
       fastq-pair CopyToBin
       COMMAND ${CMAKE_COMMAND} -E copy  ${CMAKE_BINARY_DIR}/externalProject/bin/bin/fastq_pair ${CMAKE_BINARY_DIR}/externalProject/bin
       COMMAND ${CMAKE_COMMAND} -E remove_directory  ${CMAKE_BINARY_DIR}/externalProject/bin/bin/
       DEPENDEES install
       )


You also have to add similar instructions such that ``fastq_pair`` is found in the ``PATH`` when using the :ref:`run-profile-singularity` or :ref:`run-profile-docker` profiles. To do so, add in the scope ``params.geniac.containers.cmd.post`` of  the ``conf/geniac.config`` file the following:

::

   params {
     geniac {
       containers {
         cmd {
             post {
                 fastqpair = ['cp /usr/local/bin/fastqpair/bin/fastq_pair /usr/local/bin/fastqpair/ ', 'rm -rf /usr/local/bin/fastqpair/bin']
             }
        }
       }
     }
   }


Create a bash wrapper for the tool to set required environment variables
========================================================================

The tool may require some environment variables but their values may also depend on the installation destination folder itself. This is the case for the tool ``bamcmp`` which depends on the availability of the ``htslib`` of which its ``PATH`` must be defined in the ``LD_LIBRARY_PATH`` environment variable. In that case, the folder ``modules/fromSource/bamcmp`` must not directly contain the source code but a bash wrapper and subfolders including the source code of ``bamcmp`` itself in the folder ``modules/fromSource/bamcmp/bamcmp``.


The first step consist in writing the bash wrapper ``modules/fromSource/bamcmp/bamcmp.sh`` and set the expected variables (such as ``LD-LD_LIBRARY_PATH``):

::

   #! /bin/bash
   
   export LD_LIBRARY_PATH=$(dirname $(readlink -f $0))/htslib/lib:${LD_LIBRARY_PATH}
   
   $(dirname $(readlink -f $0))/bamcmpbin/bamcmp $@


This wrapper expects to find relatively to its location (once installed) both  ``htslib`` and the original ``bamcmp`` binary. Therefore, the environment variable has to be properly set such that ``bamcmp`` can find ``htslib`` which is also installed during the installation process. This is explained in :ref:`from-source-example-include`.

The second step consist in writing the ``modules/fromSource/bamcmp/CMakeLists.txt`` to correctly install the wrapper with execution permission and the exact same name as the original binary. Therefore, it should contain an ``install`` directive to install the compiled code in the folder ``bamcmpbin``. This folder name must to be something different from the name of the binary as it will be available at the same level in the folder tree. Then it should contain another ``install`` directive to rename the bash wrapper with the expected name. The ``modules/fromSource/bamcmp/CMakeLists.txt`` must contain:

::

   ### bamcmp executable
   install(FILES ${CMAKE_BINARY_DIR}/src/bamcmp/build/bamcmp DESTINATION ${CMAKE_INSTALL_PREFIX}/bamcmpbin PERMISSIONS OWNER_READ GROUP_READ OWNER_EXECUTE GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
   
   ### bash wrapper for bamcmp with LD_LIBRARY_PATH set with htslib
   install(FILES ${CMAKE_BINARY_DIR}/src/bamcmp.sh DESTINATION ${CMAKE_INSTALL_PREFIX} RENAME bamcmp PERMISSIONS OWNER_READ GROUP_READ OWNER_EXECUTE GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
   
.. _from-source-example-include:

Include source code from required dependencies
==============================================

The tool may require other dependencies in order to compile. This is the case for the tool ``bamcmp`` which depends on ``htslib``. Therefore, the ``htslib`` source code must be included in  ``modules/fromSource/bamcmp/htslib``. The ``modules/fromSource/bamcmp/CMakeLists.txt`` file contains two |cmakeexternalproject|_  functions, the first one installs ``htslib``, the second one installs ``bamcmp`` after ``htslib`` thus requiring the ``DEPENDS htslib`` argument:

::

   ##############
   ### htslib ###
   ##############
   
   ExternalProject_Add(
       htslib
       SOURCE_DIR ${CMAKE_BINARY_DIR}/src/htslib
       CONFIGURE_COMMAND autoreconf && ./configure --prefix=${CMAKE_BINARY_DIR}/htslib
       BUILD_IN_SOURCE ON
       BUILD_COMMAND     make
       INSTALL_COMMAND   make install
      )
   
   install(DIRECTORY ${CMAKE_BINARY_DIR}/htslib
           DESTINATION ${CMAKE_INSTALL_PREFIX})
   
   ##############
   ### bamcmp ###
   ##############
   
   ExternalProject_Add(
       bamcmp
       SOURCE_DIR ${CMAKE_BINARY_DIR}/src/bamcmp
       CONFIGURE_COMMAND HTSLIBDIR=${CMAKE_BINARY_DIR}/htslib make
       BUILD_IN_SOURCE ON
       BUILD_COMMAND     ""
       INSTALL_COMMAND   ""
       DEPENDS htslib
      )
   
Set custom configure, build and install commands
================================================

The installation script from the source code which is retrieved from third parties may not be based on |cmake|_ however we use |cmake|_ for the installation. Custom commands maybe defined to tackle any situation using ``CONFIGURE_COMMAND``, ``BUILD_COMMAND`` and ``INSTALL_COMMAND`` arguments in the |cmakeexternalproject|_ function. This is the case for ``bamcmp`` as detailed in :ref:`from-source-example-include`.
