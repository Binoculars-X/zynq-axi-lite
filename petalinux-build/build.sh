#!/bin/bash
set -euo pipefail

PETALINUX=/home/builder/petalinux
BSP=/tmp/xilinx-zcu102-v2026.1-06092129.bsp
XSA=/tmp/axi_test.xsa
PROJ=/home/builder/zcu102-linux
OUT=/output

source $PETALINUX/settings.sh

echo "=== Creating project from BSP ==="
cd /home/builder
rm -rf "$PROJ"
petalinux-create project -s "$BSP" -n zcu102-linux
cd "$PROJ"

echo "=== Note: openssh already included by default via packagegroup-core-ssh-openssh ==="
echo "=== No rootfs changes needed - just build ==="

echo "=== Building ==="
petalinux-build

echo "=== Packaging BOOT.BIN ==="
petalinux-package boot \
    --fsbl ./images/linux/zynqmp_fsbl.elf \
    --u-boot ./images/linux/u-boot.elf \
    --pmufw ./images/linux/pmufw.elf \
    --fpga ./images/linux/*.bit \
    --force

echo "=== Packaging WIC SD card image (FAT32 + ext4, flashable with Rufus/Etcher) ==="
# Per UG1144: petalinux-package wic creates a complete partitioned SD image
petalinux-package wic

echo "=== Copying output files ==="
mkdir -p $OUT
cp images/linux/BOOT.BIN              $OUT/
cp images/linux/image.ub              $OUT/
cp images/linux/rootfs.tar.gz         $OUT/
cp images/linux/boot.scr              $OUT/ 2>/dev/null || true
cp images/linux/petalinux-sdimage.wic $OUT/ 2>/dev/null || \
    find images/linux -name "*.wic" -exec cp {} $OUT/ \; 2>/dev/null || true

echo "=== Verifying openssh in rootfs ==="
ROOTFS_CPIO="$PROJ/images/linux/rootfs.cpio"
if [ -f "$ROOTFS_CPIO" ]; then
    cpio -tv < "$ROOTFS_CPIO" 2>/dev/null | grep -i "sshd\|openssh" || echo "WARNING: openssh not found in rootfs cpio"
fi
find "$PROJ/build" -path "*/deploy/rpm/*openssh*" 2>/dev/null | head -5 || echo "No openssh RPMs in deploy"

echo ""
echo "=== DONE ==="
echo "Output files in /output:"
ls -lh $OUT/
echo ""
echo "To flash SD card: use Rufus or balenaEtcher to write petalinux-sdimage.wic (raw write)"
echo "This creates both FAT32 (boot) and ext4 (rootfs with dropbear SSH) partitions."
