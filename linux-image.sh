#!/bin/bash
set -x
export PATH=$PWD/gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu/bin:$PATH
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
IMAGE_FILE_NAME="aml-s905x-cc-ubuntu-xenial-${IMAGE_VERSION}-${IMAGE_LINUX_VERSION}-${IMAGE_FILE_SUFFIX}.img"
if [ $RAM -ne 0 ]; then
	IMAGE_FOLDER="ram/"
fi
mkdir -p "$IMAGE_FOLDER"
if [ $RAM -ne 0 ]; then
	mount -t tmpfs -o size=1G tmpfs $IMAGE_FOLDER
fi
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
IMAGE_LOOP_DEV="$(losetup --show -f ${IMAGE_FOLDER}${IMAGE_FILE_NAME})"
IMAGE_LOOP_DEV_BOOT="${IMAGE_LOOP_DEV}p1"
IMAGE_LOOP_DEV_ROOT="${IMAGE_LOOP_DEV}p2"
partprobe "${IMAGE_LOOP_DEV}"
mkfs.vfat -n BOOT "${IMAGE_LOOP_DEV_BOOT}"
mkfs.btrfs -f -L ROOT "${IMAGE_LOOP_DEV_ROOT}"
mkdir -p p1 p2
mount "${IMAGE_LOOP_DEV_BOOT}" p1
mount "${IMAGE_LOOP_DEV_ROOT}" p2
btrfs subvolume create p2/@
sync
umount p2
mount -o compress=lzo,noatime,subvol=@ "${IMAGE_LOOP_DEV_ROOT}" p2

PATH=$PWD/gcc/bin:$PATH make -C ${IMAGE_VERSION} ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- install INSTALL_PATH=$PWD/p1/
mkimage -A arm64 -O linux -T kernel -C none -a $IMAGE_LINUX_LOADADDR -e $IMAGE_LINUX_LOADADDR -n linux-$IMAGE_LINUX_VERSION -d p1/vmlinuz-$IMAGE_LINUX_VERSION p1/uImage
#cp ${IMAGE_VERSION}/arch/arm64/boot/Image p1/Image
cp ${IMAGE_VERSION}/arch/arm64/boot/dts/$IMAGE_DEVICE_TREE.dtb p1/${IMAGE_DEVICE_TREE##*/}.dtb
PATH=$PWD/gcc/bin:$PATH make -C ${IMAGE_VERSION} ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- headers_install INSTALL_HDR_PATH=$PWD/p2/usr/
PATH=$PWD/gcc/bin:$PATH make -C ${IMAGE_VERSION} ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- modules_install INSTALL_MOD_PATH=$PWD/p2/
PATH=$PWD/gcc/bin:$PATH make -C ${IMAGE_VERSION} ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- firmware_install INSTALL_FW_PATH=$PWD/p2/

# Mali Kernel driver
git clone https://github.com/superna9999/meson_gx_mali_450 -b DX910-SW-99002-r7p0-00rel1_meson_gx --depth 1
(cd meson_gx_mali_450 && KDIR=$PWD/../$IMAGE_VERSION ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- ./build.sh)
VER=$(ls p2/lib/modules/)
sudo cp meson_gx_mali_450/mali.ko p2/lib/modules/$VER/kernel/
sudo depmod -b p2/ -a $VER
rm -fr meson_gx_mali_450

mkdir -p p2/etc/apt/apt.conf.d p2/etc/dpkg/dpkg.cfg.d
echo "force-unsafe-io" > "p2/etc/dpkg/dpkg.cfg.d/dpkg-unsafe-io"
if [ -n "$PROXY" ] ; then
	http_proxy="$PROXY" qemu-debootstrap --arch arm64 xenial p2
else
	qemu-debootstrap --arch arm64 xenial p2
fi
tee p2/etc/apt/sources.list.d/ubuntu-ports.list <<EOF
deb http://ports.ubuntu.com/ubuntu-ports/ xenial universe multiverse restricted
deb http://ports.ubuntu.com/ubuntu-ports/ xenial-updates main universe multiverse restricted
deb http://ports.ubuntu.com/ubuntu-ports/ xenial-security main universe multiverse restricted
EOF
tee p2/etc/fstab <<EOF
/dev/root	/	btrfs	defaults,compress=lzo,noatime,subvol=@ 0 1
EOF
if [ -n "$PROXY" ] ; then
	tee "p2/etc/apt/apt.conf.d/30proxy" <<EOF
Acquire::http::proxy "http://127.0.0.1:3142";
EOF
fi

# libMali X11
wget https://github.com/superna9999/meson_gx_mali_450/releases/download/for-4.12/buildroot_openlinux_kernel_3.14_wayland_20170630_mali.tar.gz
tar xfz buildroot_openlinux_kernel_3.14_wayland_20170630_mali.tar.gz
rm buildroot_openlinux_kernel_3.14_wayland_20170630_mali.tar.gz

mkdir -p p2/usr/lib/mali
cp buildroot_openlinux/buildroot/package/meson-mali/lib/arm64/r7p0/m450/libMali.so p2/usr/lib/mali/
cd p2/usr/lib/mali
ln -s libMali.so libGLESv2.so.2.0
ln -s libMali.so libGLESv1_CM.so.1.1
ln -s libMali.so libEGL.so.1.4
ln -s libGLESv2.so.2.0 libGLESv2.so.2
ln -s libGLESv1_CM.so.1.1 libGLESv1_CM.so.1
ln -s libEGL.so.1.4 libEGL.so.1
ln -s libGLESv2.so.2 libGLESv2.so
ln -s libGLESv1_CM.so.1 libGLESv1_CM.so
ln -s libEGL.so.1 libEGL.so
cd -
cp -ar buildroot_openlinux/buildroot/package/meson-mali/include/* p2/usr/include/
echo /usr/lib/mali > p2/etc/ld.so.conf.d/mali.conf
rm -fr buildroot_openlinux

cp /usr/bin/qemu-aarch64-static p2/usr/bin/
cp stage2.sh p2/root
mount -o bind /dev p2/dev
mount -o bind /dev/pts p2/dev/pts
chroot p2 /root/stage2.sh
umount p2/dev/pts
umount p2/dev
rm p2/root/stage2.sh
if [ -n "$PROXY" ] ; then
	rm p2/etc/apt/apt.conf.d/30proxy
fi
rm p2/etc/dpkg/dpkg.cfg.d/dpkg-unsafe-io

cp binary-amlogic/boot.init p1/

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
