umount p2/proc p2/sys p2/dev p2/run
rm -fr bsdtar
rm ArchLinuxARM-aarch64-latest.tar.gz
umount -l p1 p2
losetup -D
rm -fr p1 p2 img meson_gx_mali_450
