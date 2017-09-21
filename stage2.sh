#!/bin/bash
set -eux -o pipefail

mount -t proc proc proc/
mount -t sysfs sys sys/

export DEBIAN_FRONTEND="noninteractive"
locale-gen "en_US.UTF-8"
dpkg-reconfigure locales
echo -n 'libre-computer-board' > /etc/hostname
sed -i '1 a 127.0.1.1	libre-computer-board' /etc/hosts
adduser libre --gecos "Libre Computer Board,,," --disabled-password
echo "libre:computer" | chpasswd
adduser libre sudo
apt-get update
apt-get -y dist-upgrade
apt-get install -y vim build-essential git xubuntu-core

# disable mesa EGL libs
rm /etc/ld.so.conf.d/*_EGL.conf
ldconfig

git clone git@github.com:superna9999/xf86-video-armsoc.git -b meson-drm
cd xf86-video-armsoc
./configure
make install
mkdir -p /etc/X11
cp xorg.conf /etc/X11/
cd -
rm -fr xf86-video-armsoc

umount /proc /sys

