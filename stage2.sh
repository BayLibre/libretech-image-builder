#!/bin/bash
set -eux -o pipefail

mount -t proc proc proc/
mount -t sysfs sys sys/

locale-gen "en_US.UTF-8"
echo -n 'libre-computer-board' > /etc/hostname
sed -i '1 a 127.0.1.1	libre-computer-board' /etc/hosts

echo "/dev/mmcblk1p2 / ext4 defaults 0 1" >> /etc/fstab

pacman -Syyu --noconfirm
pacman -Sq --noconfirm gnome
pacman -Sq --noconfirm gdm

systemctl enable gdm.service

rm /etc/resolv.conf
ln -s /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

systemctl enable systemd-networkd.service
systemctl enable systemd-resolved.service

echo "[Match]
Name=en*

[Network]
DHCP=yes" > /etc/systemd/network/50-wired.network

useradd -mU libre --comment "Libre Computer Board,,," --password ""
echo "libre:computer" | chpasswd
groupmems -g audio -a libre
groupmems -g video -a libre

umount /proc /sys
