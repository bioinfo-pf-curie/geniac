FROM alpine:3.7

RUN mkdir -p /opt

ADD myDependency.sh /opt/myDependency.sh

RUN apk update
RUN apk add bash
RUN bash /opt/myDependency.sh

ENV LC_ALL C
ENV PATH /usr/games:$PATH

