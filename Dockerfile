FROM nvidia/cuda:12.5.1-devel-ubuntu24.04 AS builder

# Set environment variables for non-interactive installs.
ENV DEBIAN_FRONTEND=noninteractive

# Update the package list and install necessary build dependencies.
# This includes cmake, g++, openmpi, and python3 tools.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    cmake \
    g++ \
    libopenmpi-dev \
    python3 \
    python3-dev \
    python3-pip \
    python3-numpy \
    python3-scipy \
    wget \
    curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set the working directory for the source code.
WORKDIR /app

# Copy the local LAMMPS and ML-MIX source directories into the container.
# This assumes the Dockerfile is in a parent directory of both 'lammps' and 'ML-MIX'.
COPY ./lammps /app/lammps
COPY ./ML-MIX /app/ML-MIX

WORKDIR /app/ML-MIX/LAMMPS_plugin

RUN ./install.sh /app/lammps

# Set up
RUN mkdir -p /app/lammps/build

WORKDIR /app/lammps/build

RUN wget -O libpace.tar.gz https://github.com/wcwitt/lammps-user-pace/archive/main.tar.gz

# Make CUDA stubs available and persist in env vars
RUN ln -s /usr/local/cuda/lib64/stubs/libcuda.so /usr/local/cuda/lib64/stubs/libcuda.so.1 || true
ENV LIBRARY_PATH=/usr/local/cuda/lib64/stubs:${LIBRARY_PATH}
ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64/stubs:${LD_LIBRARY_PATH}


# Configure LAMMPS with CMake.
RUN cmake ../cmake \
    -D CMAKE_CXX_COMPILER=/app/lammps/lib/kokkos/bin/nvcc_wrapper \
    -D CMAKE_BUILD_TYPE=Release \
    -D BUILD_MPI=on \
    -D PKG_KOKKOS=yes \
    -D Kokkos_ENABLE_SERIAL=ON \
    -D Kokkos_ARCH_ADA89=yes \
    -D BUILD_SHARED_LIBS=yes \
    -D BUILD_OMP=ON \
    -D Kokkos_ENABLE_CUDA=yes \
    -D CMAKE_INSTALL_PREFIX=$VIRTUAL_ENV \
    -D PACELIB_MD5=$(md5sum libpace.tar.gz | awk '{print $1}') \
    -D PKG_ML-UF3=yes \
    -D PKG_ML-PACE=yes \
    -D PKG_ML-SNAP=yes \
    -D PKG_RIGID=yes \
    -D PKG_MANYBODY=yes \
    -D PKG_MOLECULE=yes \
    -D PKG_EXTRA-PAIR=yes

RUN cmake --build . -j 20 

RUN cmake --install . 

# Build command
# docker build -t lammps-ml-mix:latest .

# Build command for debug (with log file)
# docker build -t lammps-ml-mix:latest . > build.log 2>&1

# Build command for debug (removing cache and log file)
# docker build --no-cache -t lammps-ml-mix:latest . > build.log 2>&1

# Run command
# docker run --rm -it --gpus all lammps-ml-mix:latest