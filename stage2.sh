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

apt-get install -y vim
apt-get install -y dbus
service dbus start
apt-get install -y xubuntu-desktop
service dbus stop

# Clean up packages
apt-get -y clean
apt-get -y autoclean

umount /proc /sys
