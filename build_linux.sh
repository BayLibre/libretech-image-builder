#!/usr/bin/env bash

git clone https://github.com/libre-computer-project/libretech-linux.git -b linux-4.14/libretech-cc-master-stable --depth 1 linux-libretech

set -o errexit
set -o pipefail
set -o nounset

export PATH=$PWD/gcc-linaro-6.4.1-2017.08-x86_64_aarch64-linux-gnu/bin:$PATH
pushd linux-libretech
make ARCH=arm64 defconfig
sed -i 's/CONFIG_DRM_FBDEV_OVERALLOC=100/CONFIG_DRM_FBDEV_OVERALLOC=300/g' .config
sed -i 's/CONFIG_BTRFS_FS=m/CONFIG_BTRFS_FS=y/' .config
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j`nproc`
popd
