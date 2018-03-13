#!/bin/dash
set -eux

mount -t proc proc proc/
mount -t sysfs sys sys/

echo -n 'libre-computer-board' > /etc/hostname
sed -i '1 a 127.0.1.1	libre-computer-board' /etc/hosts
adduser libre --gecos "Libre Computer Board,,," --disabled-password
echo "libre:computer" | chpasswd
echo "root:root" | chpasswd
adduser libre sudo
adduser libre audio
adduser libre dialout
adduser libre video
apt-get update
apt-get -y dist-upgrade
apt-get -y install isc-dhcp-client net-tools kmod

umount /proc /sys
