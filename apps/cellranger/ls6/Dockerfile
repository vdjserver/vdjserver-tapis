FROM ubuntu:24.04

LABEL maintainer="VDJServer"

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    wget \
    curl \
    git \
    samtools \
    tar \
    gzip \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Install Python packages
RUN pip3 install --no-cache-dir \
    numpy \
    pandas \
    matplotlib \
    scipy \
    airr==v1.4.1 \
    seaborn \
    biopython

WORKDIR /opt

# Copy local Cell Ranger archive
COPY cellranger-10.0.0.tar.gz .

# Extract
RUN tar -xzf cellranger-10.0.0.tar.gz && \
    rm cellranger-10.0.0.tar.gz

ENV PATH="/opt/cellranger-10.0.0:${PATH}"

WORKDIR /data

CMD ["/bin/bash"]