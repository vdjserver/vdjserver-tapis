FROM ubuntu:20.04

LABEL maintainer="VDJServer"

RUN export DEBIAN_FRONTEND=noninteractive && apt-get update && apt-get install -y --fix-missing \
    git \
    python3 \
    python3-pip \
    python3-sphinx \
    python3-scipy \
    libyaml-dev \
    r-base \
    r-base-dev \
    wget \
    curl \
    jq \
    bsdmainutils \
    nano

RUN pip3 install \
    pandas \
    biopython \
    matplotlib \
    airr==v1.4.1 \
    tapipy

# Copy source
RUN mkdir /vdjserver-tapis
COPY . /vdjserver-tapis

# old-style Agave V2 CLI
#ENV PATH /vdjserver-agave/agave-cli/bin:$PATH