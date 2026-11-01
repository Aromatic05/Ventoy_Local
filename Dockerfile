FROM debian:12-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        acpica-tools autoconf autogen automake autopoint binutils bison bsdextrautils bzip2 ca-certificates ccache cpio \
        dos2unix dosfstools flex g++ gcc gcc-multilib gettext gnu-efi libdevmapper-dev \
        libfreetype6-dev libfuse-dev libmpfr-dev libpciaccess-dev libusb-1.0-0-dev \
        genisoimage grub-common isolinux libc6-dev-i386 liblzma-dev libtool libxpm-dev lz4 make mtools nasm net-tools open-iscsi \
        pkg-config python-is-python3 python3-distutils qemu-system-x86 qemu-utils rsync samba squashfs-tools syslinux-common \
        unzip uuid-dev wget xorriso xz-utils zip zlib1g-dev && \
    rm -rf /var/lib/apt/lists/*

RUN wget -q https://ftpmirror.gnu.org/autoconf/autoconf-2.69.tar.xz && \
    tar -xf autoconf-2.69.tar.xz && \
    cd autoconf-2.69 && \
    ./configure --prefix=/opt/autotools && \
    make -j"$(nproc)" && \
    make install && \
    cd .. && \
    wget -q https://ftpmirror.gnu.org/automake/automake-1.15.1.tar.xz && \
    tar -xf automake-1.15.1.tar.xz && \
    cd automake-1.15.1 && \
    ./configure --prefix=/opt/autotools && \
    make -j"$(nproc)" && \
    make install && \
    cd .. && \
    rm -rf autoconf-2.69 autoconf-2.69.tar.xz automake-1.15.1 automake-1.15.1.tar.xz

RUN mkdir -p /opt/ccache/bin && \
    for compiler in \
        cc c++ gcc g++ musl-gcc \
        aarch64-buildroot-linux-uclibc-gcc \
        aarch64-linux-gcc aarch64-linux-gnu-gcc aarch64-linux-gnu-g++ \
        mips-linux-gnu-gcc mips-linux-gnu-g++ \
        mips64el-linux-musl-gcc x86_64-linux-gnu-gcc; do \
        ln -s /usr/bin/ccache /opt/ccache/bin/$compiler; \
    done

ENV PATH=/opt/autotools/bin:/opt/ccache/bin:$PATH \
    ACLOCAL_PATH=/usr/share/aclocal \
    CCACHE_BASEDIR=/ventoy \
    CCACHE_COMPILERCHECK=content \
    CCACHE_DIR=/ventoy/.cache/ccache \
    CCACHE_NOHASHDIR=true

CMD cd /ventoy/INSTALL && ls -la && sh docker_ci_build.sh    
