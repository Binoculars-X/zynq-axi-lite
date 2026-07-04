FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Use bash as default shell (required by PetaLinux)
SHELL ["/bin/bash", "-c"]
RUN ln -sf /bin/bash /bin/sh

# Complete PetaLinux 2026.1 package list per UG1144 for Ubuntu 22.04
RUN apt-get update && apt-get install -y \
    autoconf \
    bc \
    bison \
    build-essential \
    chrpath \
    gcc-multilib \
    libtool \
    cpio \
    curl \
    debianutils \
    diffstat \
    dnsutils \
    fakeroot \
    file \
    flex \
    gawk \
    gcc \
    git \
    gnupg \
    iproute2 \
    iputils-ping \
    lib32z1 \
    libegl1-mesa \
    libglib2.0-dev \
    libncurses5-dev \
    libsdl1.2-dev \
    libssl-dev \
    libtinfo5 \
    locales \
    lsb-release \
    net-tools \
    python3 \
    python3-git \
    python3-jinja2 \
    python3-pexpect \
    python3-pip \
    rsync \
    socat \
    sudo \
    texinfo \
    tftpd-hpa \
    unzip \
    wget \
    xterm \
    xz-utils \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Locale required by PetaLinux
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Create build user (PetaLinux refuses to run as root)
RUN useradd -m -s /bin/bash builder && \
    echo "builder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Copy installer and BSP
COPY petalinux-v2026.1-06061130-installer.run /tmp/
COPY xilinx-zcu102-v2026.1-06092129.bsp /tmp/

RUN chmod +x /tmp/petalinux-v2026.1-06061130-installer.run

# Install PetaLinux as builder user
USER builder
WORKDIR /home/builder

RUN /tmp/petalinux-v2026.1-06061130-installer.run \
    --dir /home/builder/petalinux \
    --platform aarch64 \
    -y \
    && echo "PetaLinux installed"

# Build script — runs at container start
COPY build.sh /home/builder/build.sh
RUN sudo chmod +x /home/builder/build.sh

ENTRYPOINT ["/bin/bash", "/home/builder/build.sh"]
