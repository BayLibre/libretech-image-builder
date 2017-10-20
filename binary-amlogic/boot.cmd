setenv bootargs console=ttyAML0 root=/dev/mmcblk1p2 rootfstype=btrfs rootflags=subvol=@ rootwait console=ttyAML0,115200 no_console_suspend
fatload ${devtype} ${devnum} $fdt_addr_r $fdtfile
fatload ${devtype} ${devnum} $kernel_addr_r Image
booti $kernel_addr_r - $fdt_addr_r
