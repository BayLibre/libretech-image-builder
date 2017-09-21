LibreTech CC Ubuntu 16.04 Image Build Script
============================================

Prerequesite
============

On an Ubuntu 16.04 x86_64/AMD64 system :

```
# sudo apt install build-essential bc git qemu debootstrap qemu-user-static
```

Steps
=====

```
# ./init.sh
# ./build_linux.sh
# sudo ./linux-image.sh
# sudo ./clean.sh
```

Image will be in the same directory.

Simply dd it onto an SDCard like :

```
# sudo dd if=aml-s905x-cc-ubuntu-xenial-linux-libretech-4.13.3-g5bb7f41-2017-09-21.img of=/dev/mmcblk0 bs=8M
```

Enjoy !
