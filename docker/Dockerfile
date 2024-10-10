# Use a lightweight Debian base image
FROM debian:bullseye-slim

# Install necessary dependencies
RUN apt-get update && \
    apt-get install -y \
    curl \
    locales \
    ca-certificates \
    build-essential \
    procps \
    unzip \
    zip \
    wget \
    jq \
    python3 \
    python3-pip \
    git && \
    # Generate en_GB.UTF-8 locale
    echo "en_GB.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen && \
    update-locale LANG=en_GB.UTF-8 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set locale-related environment variables
# Required for XML output in nf-test.
ENV LANG en_GB.UTF-8
ENV LANGUAGE en_GB:en
ENV LC_ALL en_GB.UTF-8

# Supress safe directory warning
RUN git config --global --add safe.directory '*'

# Install kislyuk/yq (Python-based yq)
RUN pip3 install yq && \
        yq --version

# Install nextflow & nf-test first. This ensures the setup works before installing other tools
COPY build_files/nextflow.sh \
        build_files/nf-test.sh \
        /root/buildscripts/

RUN /root/buildscripts/nextflow.sh && /root/buildscripts/nf-test.sh

WORKDIR /
