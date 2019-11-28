FROM conda/miniconda3-centos7

LABEL description="Docker image containing all requirements for RNA-seq pipeline"

RUN conda config --add channels defaults && conda config --add channels conda-forge && conda config --add channels bioconda
RUN conda install -y which && ln -s /usr/local/bin/which /usr/bin/which
RUN conda install -y conda-forge::r-markdown=0.8 
RUN conda clean -a

ENV LANG=en_US.UTF LC_ALL=en_US.UTF-8 
