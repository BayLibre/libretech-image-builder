umount p2/proc p2/sys p2/dev p2/run
umount -l p1 p2
rm -fr p1 p2 img meson_gx_mali_450
losetup -d /dev/loop0
