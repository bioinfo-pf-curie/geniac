FROM conda/miniconda3-centos7

LABEL description="Docker image containing all requirements for RNA-seq pipeline"

RUN conda config --add channels defaults && conda config --add channels conda-forge && conda config --add channels bioconda
RUN conda install -y which && ln -s /usr/local/bin/which /usr/bin/which
RUN conda install -y conda-forge::r-data.table=1.11.4
RUN conda install -y conda-forge::r-gplots=3.0.1 
RUN conda install -y bioconda::bioconductor-edger=3.22.5
RUN conda install -y bioconda::bioconductor-deseq2=1.22.1 
RUN conda install -y libgfortran=3.0.0=1
RUN conda clean -a 

ENV LANG=en_US.UTF LC_ALL=en_US.UTF-8 
