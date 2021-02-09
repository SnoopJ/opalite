FROM ubuntu:18.04 as base

# prevents tzdata (or other packages) from hanging the installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=US/Eastern

ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

RUN ln -snf /usr/share/zone/info/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
    apt-get update && \
    apt-get install -y \
        automake \
        build-essential \
        cmake \
        g++ \
        gfortran \
        git \
        vim \
        make \
        pkg-config \
        unzip \
        curl \
        wget \
        libopenmpi-dev \
        libboost-dev libboost-filesystem-dev libboost-regex-dev libboost-system-dev \
        libgsl-dev \
        trilinos-dev \
        libopenblas-dev && \
    apt-get install -y \
        python3 \
        python3-pip \
        python3-venv && \
    python3 -m pip install --upgrade pip && \
    python3 -m pip install "numpy==1.19.1"

## add local user
RUN useradd -m pearl && \
    chown -R pearl /opt/ && \
    chown -R pearl /home/pearl

FROM base AS compile

RUN git clone --depth=1 --branch=hdf5-1_8_21 https://github.com/HDFGroup/hdf5 /tmp/hdf5-1.8.21_src
WORKDIR /tmp/hdf5-1.8.21_src
RUN CC=mpicc ./configure --enable-parallel --prefix=/usr/local/hdf5 && \
    make -j$(($(nproc) - 1)) && \
    make install

WORKDIR /opt/H5Hut_src
RUN git clone --branch H5hut-2.0.0rc6 https://gitlab.psi.ch/H5hut/src.git /opt/H5Hut_src &&\
    git checkout 5f57c23 && \
    ./autogen.sh && \
    CC=mpicc CXX=mpicxx FC=mpif90 ./configure --prefix=/usr/local/H5Hut --enable-parallel --enable-shared --with-hdf5=/usr/local/hdf5 && \
    make -j$(($(nproc) - 1)) && \
    make install

WORKDIR /opt/OPAL_src
# jgerity: I can't compile without these changes to the cmake config, most of
# the replacements below are old(?) usage of STRING MATCH that is NERSC specific
# Dropping the array-bounds error is related to a fix included in 2.0, see d5af9f6a
RUN git clone --depth=1 --branch=OPAL-1.6.2 https://gitlab.psi.ch/OPAL/src.git /opt/OPAL_src && \
    sed -i -e "45s/-Werror\S*//g" CMakeLists.txt && \
    sed -i -e "165,199s/\(.*\)/#\1/" CMakeLists.txt && \
    \
    sed -i -e "11s/\(.*\)/#\1/" src/CMakeLists.txt && \
    sed -i -e "27,31s/\(.*\)/#\1/" src/CMakeLists.txt && \
    sed -i -e "103,115s/\(.*\)/#\1/" src/CMakeLists.txt && \
    sed -i -e "128s/\(.*\)/#\1/" src/CMakeLists.txt && \
    mkdir build

RUN cd build && \
    CC=mpicc \
    CXX=mpicxx \
    H5HUT_PREFIX=/usr/local/H5Hut \
    HDF5_PREFIX=/usr/local/hdf5 \
    HDF5_ROOT=/usr/local/hdf5 \
        cmake .. && \
    cmake --build . -- -j$(($(nproc) - 2)) -l$(($(nproc) - 2))

FROM base AS final

COPY --from=compile /opt/OPAL_src /opt/OPAL_src
COPY --from=compile /usr/local/H5Hut /usr/local/H5Hut
COPY --from=compile /usr/local/hdf5 /usr/local/hdf5

RUN cmake --build /opt/OPAL_src/build --target install && \
    rm -fr /opt/OPAL_src


USER pearl
WORKDIR /home/pearl
