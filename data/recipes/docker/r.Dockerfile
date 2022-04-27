FROM 4geniac/almalinux:8.5_conda-py39_4.11.0

ENV R_LIBS_USER "-"
ENV R_PROFILE_USER "-"
ENV R_ENVIRON_USER "-"
ENV PYTHONNOUSERSITE 1
ENV PATH $PATH
ENV LC_ALL en_US.utf-8
ENV LANG en_US.utf-8
ENV BASH_ENV /opt/etc/bashrc
ENV PKG_CONFIG_PATH /usr/local/lib/pkgconfig
ENV PKG_LIBS -liconv

ARG R_MIRROR=https://cloud.r-project.org
ARG R_ENV_DIR=/opt/renv
ARG CACHE=TRUE
ARG CACHE_DIR=/opt/renv_cache

RUN conda create -y -n r_env \
&& conda install -y -c conda-forge -n r_env r-base=3.6.1=h6e652e1_3 \
&& conda clean -a \
&& echo "This is R tool!" \
&& echo -e "#! /bin/bash\n\n# script to activate the conda environment r_env" > ~/.bashrc \
&& echo "export PS1='Docker> '" >> ~/.bashrc \
&& conda init bash \
&& echo "conda activate r_env" >> ~/.bashrc \
&& mkdir -p /opt/etc \
&& cp ~/.bashrc /opt/etc/bashrc

ADD r/renv.lock ${R_ENV_DIR}/renv.lock

RUN source  /opt/etc/bashrc \
&& R -q -e "options(repos = \"${R_MIRROR}\") ; install.packages(\"renv\") ; options(renv.config.install.staged=FALSE, renv.settings.use.cache=FALSE) ; install.packages(\"BiocManager\"); BiocManager::install(version=\"3.9\", ask=FALSE) ; renv::restore(lockfile = \"${R_ENV_DIR}/renv.lock\")"

ENV PATH /usr/local/envs/r_env/bin:$PATH

ENV LC_ALL en_US.utf-8
ENV LANG en_US.utf-8

