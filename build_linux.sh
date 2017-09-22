git clone https://github.com/libre-computer-project/libretech-linux.git -b linux-4.13/libretech-cc-overlays --depth 1 linux-libretech
cd linux-libretech
git apply ../patches/0001-meson_drm_disable_ARGB8888.patch
make ARCH=arm64 meson_defconfig
PATH=$PWD/../gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu/bin:$PATH make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j4
cd -
