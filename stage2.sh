#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

mount -t proc proc proc/
mount -t sysfs sys sys/

export DEBIAN_FRONTEND="noninteractive"
locale-gen "en_US.UTF-8"
dpkg-reconfigure locales

echo ttyAML0 >> /etc/securetty
echo tty0 >> /etc/securetty
cat > /etc/init/ttyAML0.conf <<EOF
start on stopped rc RUNLEVEL=[12345]
stop on runlevel [!12345]
respawn
exec /sbin/getty -L 115200 ttyAML0
EOF

# Configure names
echo -n 'libretech-demo' > /etc/hostname
sed -i '1 a 127.0.1.1  libretech-demo' /etc/hosts
adduser libre --gecos "Libre Computer Board,,," --disabled-password
echo "libre:computer" | chpasswd
adduser libre sudo
adduser libre audio
adduser libre dialout
adduser libre video

# Update the distribution
apt-get update
apt-get -y dist-upgrade
apt-get -y clean
apt-get -y autoclean

ldconfig

apt-get install -y build-essential git libtool automake autoconf alsa-utils libudev-dev unzip libasound2-dev udev

# Build and install forked mali FBDEV SDL library
git clone -b meson-gx https://github.com/superna9999/libsdl2-2.0.2-dfsg1 --depth 1
pushd libsdl2-2.0.2-dfsg1
./configure --without-x --enable-video-opengles --disable-video-opengl --enable-video-mali --disable-video-x11 --disable-video-wayland
make -j`nproc` install
popd
rm -r libsdl2-2.0.2-dfsg1

# Build and install ioquake3
git clone -b meson-gx https://github.com/superna9999/ioq3 --depth 1
pushd ioq3
make -j`nproc` SDL_LIBS="-L /usr/local/lig -Wl,-rpath,/usr/local/lib -lSDL2" SDL_CFLAGS="-I/usr/local/include/SDL2" PLATFORM_HACK=gles BUILD_RENDERER_OPENGL2=0 USE_RENDERER_DLOPEN=0
popd

# Add systemd service to start quake3 on boot
cat > /etc/systemd/system/frag.service <<EOF
[Unit]
Description=Q3DEMO
After=systemd-udev-trigger.service systemd-udevd.service

[Service]
ExecStart=/ioq3/build/release-linux-aarch64/ioquake3.aarch64
KillSignal=SIGKILL
Restart=on-failure
Restart=3s

[Install]
WantedBy=graphical.target
EOF

# Enable q3 service
mkdir -p /etc/systemd/system/graphical.target.wants/
ln -snf /etc/systemd/system/frag.service /etc/systemd/system/graphical.target.wants/frag.service

# Basic network setup
cat > /etc/network/interfaces.d/eth0 <<EOF
allow-hotplug eth0
iface eth0 inet dhcp
EOF
mkdir -p /etc/systemd/system/network-online.target.wants/
ln -snf /lib/systemd/system/networking.service /etc/systemd/system/network-online.target.wants/networking.service

# Clean up dev packages
apt-get purge -y build-essential git libtool automake autoconf libudev-dev libasound2-dev
apt-get -y autoremove

# Clean up packages
apt-get -y clean
apt-get -y autoclean
umount /proc /sys
