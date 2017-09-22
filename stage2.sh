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
# User must be in the video group to access /dev/mali
adduser libre video
apt-get update
apt-get -y dist-upgrade
apt-get install -y vim
apt-get install -y dbus
service dbus start
apt-get install -y xubuntu-desktop
service dbus stop

# Clean up packages
apt-get -y clean
apt-get -y autoclean

# OpenGL ES
apt-get install -y mesa-utils-extra

# disable mesa EGL libs
rm /etc/ld.so.conf.d/*_EGL.conf
ldconfig

apt-get install -y build-essential git libtool automake autoconf xutils-dev xserver-xorg-dev xorg-dev libudev-dev

git clone https://github.com/superna9999/xf86-video-armsoc.git -b meson-drm
cd xf86-video-armsoc
./autogen.sh
make install
mkdir -p /etc/X11
cp xorg.conf /etc/X11/
cd -
rm -fr xf86-video-armsoc

# Clean up dev packages
apt-get purge -y build-essential git libtool automake autoconf xutils-dev xserver-xorg-dev xorg-dev libudev-dev
apt-get -y autoremove

# Clean up packages
apt-get -y clean
apt-get -y autoclean

umount /proc /sys
