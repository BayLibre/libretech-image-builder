git clone https://github.com/libre-computer-project/libretech-linux.git -b linux-4.14/libretech-cc-master-stable --depth 1 linux-libretech
cd linux-libretech
make ARCH=arm64 defconfig
sed -i 's/CONFIG_BTRFS_FS=m/CONFIG_BTRFS_FS=y/' .config
PATH=$PWD/../gcc-linaro-6.4.1-2017.08-x86_64_aarch64-linux-gnu/bin:$PATH make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j4
cd -
