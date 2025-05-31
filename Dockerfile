# Build stage
FROM ubuntu:22.04 AS builder

# Configure apt to use IPv4 and a reliable mirror
RUN echo 'Acquire::ForceIPv4 "true";' > /etc/apt/apt.conf.d/99force-ipv4 && \
    sed -i 's|archive.ubuntu.com|us.archive.ubuntu.com|g' /etc/apt/sources.list

# Avoid prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Set environment variables early
ENV MY_INSTALL_DIR=/usr/local
ENV PATH="$MY_INSTALL_DIR/bin:$PATH"
ENV LD_LIBRARY_PATH="$MY_INSTALL_DIR/lib:$MY_INSTALL_DIR/lib64"
ENV PKG_CONFIG_PATH="$MY_INSTALL_DIR/lib/pkgconfig"

# Install build dependencies
RUN apt-get update && \
    apt-get install -y \
        build-essential \
        cmake \
        curl \
        git \
        pkg-config \
        python3 \
        python3-pip \
        g++ \
        unzip \
        zip \
        bison \
        flex \
        autoconf \
        automake \
        libtool \
        linux-libc-dev \
        libsystemd-dev && \
    rm -rf /var/lib/apt/lists/*

# Install vcpkg
WORKDIR /opt
RUN git clone https://github.com/Microsoft/vcpkg.git && \
    cd vcpkg && \
    ./bootstrap-vcpkg.sh

# Install gRPC
WORKDIR /opt
RUN git clone --recurse-submodules -b v1.69.0 --depth 1 --shallow-submodules https://github.com/grpc/grpc && \
    cd grpc && \
    mkdir -p cmake/build && \
    cd cmake/build && \
    cmake -DgRPC_INSTALL=ON \
          -DgRPC_BUILD_TESTS=OFF \
          -DCMAKE_CXX_STANDARD=17 \
          -DCMAKE_INSTALL_PREFIX=$MY_INSTALL_DIR \
          ../.. && \
    make -j$(nproc) && \
    make install && \
    ldconfig

# Install required libraries via vcpkg
WORKDIR /opt/vcpkg
RUN ./vcpkg install \
    nlohmann-json:x64-linux \
    libpqxx:x64-linux \
    crow:x64-linux \
    jwt-cpp:x64-linux \
    minio-cpp:x64-linux \
    openssl:x64-linux

# Set environment variables for downstream builds
ENV VCPKG_ROOT=/opt/vcpkg
ENV VCPKG_DEFAULT_TRIPLET=x64-linux
ENV CMAKE_TOOLCHAIN_FILE=/opt/vcpkg/scripts/buildsystems/vcpkg.cmake

# Verify installations
RUN ldconfig && \
    pkg-config --modversion grpc || true && \
    ls -l $MY_INSTALL_DIR/lib/libgrpc*.so || true