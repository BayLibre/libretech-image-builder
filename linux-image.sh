#!/bin/bash
set -x
export PATH=$PWD/gcc-linaro-6.4.1-2017.08-x86_64_aarch64-linux-gnu/bin:$PATH
#RAM=1
RAM=0
#PROXY="http://127.0.0.1:3142"
PROXY=""
IMAGE_FOLDER="img/"
IMAGE_VERSION="linux-libretech"
IMAGE_DEVICE_TREE="amlogic/meson-gxl-s905x-libretech-cc"
if [ ! -z "$1" ]; then
	IMAGE_VERSION="$1"
fi
if [ ! -z "$2" ]; then
	IMAGE_DEVICE_TREE="$2"
fi
if [ ! -f "$IMAGE_VERSION/arch/arm64/boot/dts/$IMAGE_DEVICE_TREE.dts" ]; then
	echo "Missing Device Tree"
	exit 1
fi
set -eux -o pipefail
IMAGE_LINUX_LOADADDR="0x1080000"
IMAGE_LINUX_VERSION=`head -n 1 $IMAGE_VERSION/include/config/kernel.release | xargs echo -n`
IMAGE_FILE_SUFFIX="$(date +%F)"
IMAGE_FILE_NAME="aml-s905x-cc-archlinux-aarch64-${IMAGE_VERSION}-${IMAGE_LINUX_VERSION}-${IMAGE_FILE_SUFFIX}.img"
if [ $RAM -ne 0 ]; then
	IMAGE_FOLDER="ram/"
fi
mkdir -p "$IMAGE_FOLDER"
if [ $RAM -ne 0 ]; then
	mount -t tmpfs -o size=1G tmpfs $IMAGE_FOLDER
fi
truncate -s 7G "${IMAGE_FOLDER}${IMAGE_FILE_NAME}"
fdisk "${IMAGE_FOLDER}${IMAGE_FILE_NAME}" <<EOF
o
n
p
1
2048
524287
a
t
b
n
p
2
524288

p
w

EOF
IMAGE_LOOP_DEV="$(losetup --show -f ${IMAGE_FOLDER}${IMAGE_FILE_NAME})"
IMAGE_LOOP_DEV_BOOT="${IMAGE_LOOP_DEV}p1"
IMAGE_LOOP_DEV_ROOT="${IMAGE_LOOP_DEV}p2"
partprobe "${IMAGE_LOOP_DEV}"
mkfs.vfat -n BOOT "${IMAGE_LOOP_DEV_BOOT}"
mkfs.ext4 -L ROOT "${IMAGE_LOOP_DEV_ROOT}"
mkdir -p p1 p2
mount "${IMAGE_LOOP_DEV_BOOT}" p1
mount "${IMAGE_LOOP_DEV_ROOT}" p2
sync
umount p2
mount -o noatime "${IMAGE_LOOP_DEV_ROOT}" p2

mkdir bsdtar
cd bsdtar
wget https://github.com/libarchive/libarchive/archive/v3.3.1.tar.gz
tar -zxvf v3.3.1.tar.gz
cd libarchive-3.3.1
mkdir b
cd b
cmake ../
make bsdtar
cd ../../..

#download latest archlinuxarm-aarch64
wget http://archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz
bsdtar/libarchive-3.3.1/b/bin/bsdtar -xpf ArchLinuxARM-aarch64-latest.tar.gz -C p2/

rm ArchLinuxARM-aarch64-latest.tar.gz
rm -fr bsdtar

PATH=$PWD/gcc/bin:$PATH make -C ${IMAGE_VERSION} ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- install INSTALL_PATH=$PWD/p1/
cp ${IMAGE_VERSION}/arch/arm64/boot/Image p1/Image
mkdir -p p1/$(dirname $IMAGE_DEVICE_TREE)
cp ${IMAGE_VERSION}/arch/arm64/boot/dts/$IMAGE_DEVICE_TREE.dtb p1/$(dirname $IMAGE_DEVICE_TREE)
PATH=$PWD/gcc/bin:$PATH make -C ${IMAGE_VERSION} ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- headers_install INSTALL_HDR_PATH=$PWD/p2/usr/
PATH=$PWD/gcc/bin:$PATH make -C ${IMAGE_VERSION} ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- modules_install INSTALL_MOD_PATH=$PWD/p2/

# Mali Kernel driver
git clone https://github.com/superna9999/meson_gx_mali_450 -b DX910-SW-99002-r7p0-00rel1_meson_gx --depth 1
(cd meson_gx_mali_450 && KDIR=$PWD/../$IMAGE_VERSION ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- ./build.sh)
sudo cp meson_gx_mali_450/mali.ko p2/lib/modules/$IMAGE_LINUX_VERSION/kernel/
sudo depmod -b p2/ -a $IMAGE_LINUX_VERSION
rm -fr meson_gx_mali_450

# stage 2
cp $(which "qemu-aarch64-static") p2/usr/bin
cp stage2.sh p2/root
mount -o bind /dev p2/dev
mount -o bind /dev/pts p2/dev/pts
chroot p2 /root/stage2.sh
umount p2/dev/pts
umount p2/dev
rm p2/root/stage2.sh
rm p2/usr/bin/qemu-aarch64-static

# Mali udev rule
tee p2/etc/udev/rules.d/50-mali.rules <<EOF
KERNEL=="mali", MODE="0660", GROUP="video"
EOF

binary-amlogic/mkimage -C none -A arm -T script -d binary-amlogic/boot.cmd p1/boot.scr

umount p2
umount p1

dd if=binary-amlogic/u-boot.bin.sd.bin of="${IMAGE_LOOP_DEV}" conv=fsync bs=1 count=442
dd if=binary-amlogic/u-boot.bin.sd.bin of="${IMAGE_LOOP_DEV}" conv=fsync bs=512 skip=1 seek=1

losetup -d "${IMAGE_LOOP_DEV}"
mv "${IMAGE_FOLDER}${IMAGE_FILE_NAME}" "${IMAGE_FILE_NAME}"
if [ $RAM -ne 0 ]; then
	umount "${IMAGE_FOLDER}"
fi
rmdir "${IMAGE_FOLDER}"
rmdir p1 p2
