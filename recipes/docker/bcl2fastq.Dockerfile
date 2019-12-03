FROM conda/miniconda2-centos7

ADD bcl2fastq2-v2.20.0.422-Linux-x86_64.rpm /opt/bcl2fastq2-v2.20.0.422-Linux-x86_64.rpm

RUN yum install -y which \
&& cd /opt \
&& yum localinstall -y bcl2fastq2-v2.20.0.422-Linux-x86_64.rpm

ENV LC_ALL en_US.utf-8
ENV LANG en_US.utf-8
