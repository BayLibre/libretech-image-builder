#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

set -o xtrace

export PATH=$PWD/gcc-linaro-6.4.1-2017.08-x86_64_aarch64-linux-gnu/bin:$PATH

IMAGE_FOLDER="img/"
IMAGE_VERSION=${1:-linux-libretech}
IMAGE_DEVICE_TREE=${2:-amlogic/meson-gxl-s905x-libretech-cc}
export KDIR=${3:-${PWD}/${IMAGE_VERSION}}

if [ ! -f "$IMAGE_VERSION/arch/arm64/boot/dts/$IMAGE_DEVICE_TREE.dts" ]; then
	echo "Missing Device Tree"
	exit 1
fi

IMAGE_LINUX_LOADADDR="0x1080000"
IMAGE_LINUX_VERSION=`head -n 1 $IMAGE_VERSION/include/config/kernel.release | xargs echo -n`
IMAGE_FILE_SUFFIX="$(date +%F)"
IMAGE_FILE_NAME="aml-s905x-cc-ubuntu-xenial-${IMAGE_VERSION}-${IMAGE_LINUX_VERSION}-${IMAGE_FILE_SUFFIX}.img"

# Create the virtual disk image
mkdir -p "$IMAGE_FOLDER"
truncate -s 4G "${IMAGE_FOLDER}${IMAGE_FILE_NAME}"
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

# Create image partitions
IMAGE_LOOP_DEV="$(losetup --show -f ${IMAGE_FOLDER}${IMAGE_FILE_NAME})"
IMAGE_LOOP_DEV_BOOT="${IMAGE_LOOP_DEV}p1"
IMAGE_LOOP_DEV_ROOT="${IMAGE_LOOP_DEV}p2"
partprobe "${IMAGE_LOOP_DEV}"
mkfs.vfat -n BOOT "${IMAGE_LOOP_DEV_BOOT}"
mkfs.btrfs -f -L ROOT "${IMAGE_LOOP_DEV_ROOT}"
mkdir -p boot rootfs
mount "${IMAGE_LOOP_DEV_BOOT}" boot
mount "${IMAGE_LOOP_DEV_ROOT}" rootfs
btrfs subvolume create rootfs/@
sync
umount rootfs
mount -o compress=lzo,noatime,subvol=@ "${IMAGE_LOOP_DEV_ROOT}" rootfs


# Install the kernel, its headers and modules
make -C ${KDIR} ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- install INSTALL_PATH=$PWD/boot/
cp ${KDIR}/arch/arm64/boot/Image boot/Image
mkdir -p boot/$(dirname $IMAGE_DEVICE_TREE)
cp ${KDIR}/arch/arm64/boot/dts/$IMAGE_DEVICE_TREE.dtb boot/$(dirname $IMAGE_DEVICE_TREE)
make -C ${KDIR} ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- headers_install INSTALL_HDR_PATH=$PWD/rootfs/usr/
make -C ${KDIR} ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- modules_install INSTALL_MOD_PATH=$PWD/rootfs/

# Compile and install the Mali kernel driver
git clone https://github.com/superna9999/meson_gx_mali_450 -b DX910-SW-99002-r7p0-00rel1_meson_gx --depth 1
pushd meson_gx_mali_450
ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- ./build.sh
popd
VER=$(ls rootfs/lib/modules/)
cp meson_gx_mali_450/mali.ko rootfs/lib/modules/$VER/kernel/
depmod -b rootfs/ -a $VER
rm -fr meson_gx_mali_450

# Speed up apt a bit
mkdir -p rootfs/etc/apt/apt.conf.d rootfs/etc/dpkg/dpkg.cfg.d
echo "force-unsafe-io" > rootfs/etc/dpkg/dpkg.cfg.d/dpkg-unsafe-io

mkdir -p rootfs/usr/bin
cp $(which "qemu-aarch64-static") rootfs/usr/bin
debootstrap --arch arm64 --foreign xenial rootfs
chroot rootfs /debootstrap/debootstrap --second-stage

tee rootfs/etc/apt/sources.list.d/ubuntu-ports.list <<EOF
deb http://ports.ubuntu.com/ubuntu-ports/ xenial universe multiverse restricted
deb http://ports.ubuntu.com/ubuntu-ports/ xenial-updates main universe multiverse restricted
deb http://ports.ubuntu.com/ubuntu-ports/ xenial-security main universe multiverse restricted
EOF
tee rootfs/etc/fstab <<EOF
/dev/root	/	btrfs	defaults,compress=lzo,noatime,subvol=@ 0 1
EOF

# Get the mali libraries extracted from amlogic's buildroot
wget https://github.com/superna9999/meson_gx_mali_450/releases/download/for-4.12/buildroot_openlinux_kernel_3.14_wayland_20170630_mali.tar.gz
tar xfz buildroot_openlinux_kernel_3.14_wayland_20170630_mali.tar.gz
rm buildroot_openlinux_kernel_3.14_wayland_20170630_mali.tar.gz

mkdir -p rootfs/usr/lib/mali
cp buildroot_openlinux/buildroot/package/meson-mali/lib/arm64/r7p0/m450/libMali.so rootfs/usr/lib/mali/
pushd rootfs/usr/lib/mali
ln -s libMali.so libGLESv2.so.2.0
ln -s libMali.so libGLESv1_CM.so.1.1
ln -s libMali.so libEGL.so.1.4
ln -s libGLESv2.so.2.0 libGLESv2.so.2
ln -s libGLESv1_CM.so.1.1 libGLESv1_CM.so.1
ln -s libEGL.so.1.4 libEGL.so.1
ln -s libGLESv2.so.2 libGLESv2.so
ln -s libGLESv1_CM.so.1 libGLESv1_CM.so
ln -s libEGL.so.1 libEGL.so
popd
cp -ar buildroot_openlinux/buildroot/package/meson-mali/include/* rootfs/usr/include/
pushd rootfs/usr/include/EGL
ln -s ../EGL_platform/platform_fbdev/* .
popd
echo /usr/lib/mali > rootfs/etc/ld.so.conf.d/mali.conf
rm -r buildroot_openlinux

# Start custom script with arm64 emulation to build SDL and IOQuake3
cp stage2.sh rootfs/root
mount -o bind /dev rootfs/dev
mount -o bind /dev/pts rootfs/dev/pts
chroot rootfs /root/stage2.sh
umount rootfs/dev/pts
umount rootfs/dev
rm rootfs/root/stage2.sh
rm rootfs/etc/dpkg/dpkg.cfg.d/dpkg-unsafe-io

# Mali udev rule
tee rootfs/etc/udev/rules.d/50-mali.rules <<EOF
KERNEL=="mali", MODE="0660", GROUP="video"
EOF

# Install quake3 arena demo files
wget https://github.com/superna9999/ioq3/releases/download/working0/baseq3-demo.tar.gz
tar xfz baseq3-demo.tar.gz
#mkdir -p rootfs/usr/local/games/quake3/baseq3
mv baseq3-demo/* rootfs/ioq3/build/release-linux-aarch64/baseq3
rm -r baseq3-demo baseq3-demo.tar.gz

binary-amlogic/mkimage -C none -A arm -T script -d binary-amlogic/boot.cmd boot/boot.scr

# Clean up a bit
btrfs filesystem defragment -f -r rootfs
umount rootfs
umount boot

# Write bootloader preserving the MBR of the image device
dd if=binary-amlogic/u-boot.bin.sd.bin of="${IMAGE_LOOP_DEV}" conv=fsync bs=1 count=442
dd if=binary-amlogic/u-boot.bin.sd.bin of="${IMAGE_LOOP_DEV}" conv=fsync bs=512 skip=1 seek=1

losetup -d "${IMAGE_LOOP_DEV}"
mv "${IMAGE_FOLDER}${IMAGE_FILE_NAME}" "${IMAGE_FILE_NAME}"
rmdir "${IMAGE_FOLDER}"
rmdir boot rootfs
