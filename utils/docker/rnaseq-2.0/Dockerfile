FROM conda/miniconda3-centos7

LABEL description="Docker image containing all requirements for RNA-seq pipeline"

COPY environment.yml /
RUN conda env create -f /environment.yml && conda clean -a
ENV LANG=en_US.UTF LC_ALL=en_US.UTF-8 PATH /usr/local/envs/rnaseq-2.0/bin:$PATH

