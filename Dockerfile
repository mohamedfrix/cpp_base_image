# Build stage
FROM ubuntu:22.04 AS builder

# Configure apt to use IPv4
RUN echo 'Acquire::ForceIPv4 "true";' > /etc/apt/apt.conf.d/99force-ipv4

# Avoid prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    curl \
    git \
    pkg-config \
    python3 \
    python3-pip \
    g++ \
    zip \
    bison \
    flex \
    autoconf \
    automake \
    libtool \
    linux-libc-dev \
    && rm -rf /var/lib/apt/lists/*

# Install vcpkg for C++ dependencies
WORKDIR /opt
RUN git clone https://github.com/Microsoft/vcpkg.git && \
    cd vcpkg && \
    ./bootstrap-vcpkg.sh

# clone the grpc repo
WORKDIR /opt
RUN git clone --recurse-submodules -b v1.69.0 --depth 1 --shallow-submodules https://github.com/grpc/grpc && \
    cd grpc && \
    mkdir -p cmake/build && \
    cd cmake/build && \
    cmake -DgRPC_INSTALL=ON \
          -DgRPC_BUILD_TESTS=OFF \
          -DCMAKE_CXX_STANDARD=17 \
          -DCMAKE_INSTALL_PREFIX=/usr/local \
          ../.. && \
    make -j4 && \
    make install && \
    ldconfig


# Install required libraries via vcpkg
# RUN /opt/vcpkg/vcpkg install crow nlohmann-json libpqxx:x64-linux openssl:x64-linux jwt-cpp

WORKDIR /opt/vcpkg
RUN ./vcpkg install nlohmann-json libpqxx crow jwt-cpp minio-cpp openssl
