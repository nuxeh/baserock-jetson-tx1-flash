#!/bin/bash

echo "+------------------------------------------------------------------+"
echo "| Please connect the Jetson TX1 to a USB port via micro USB cable, |"
echo "| and put into recovery mode.                                      |"
echo "+------------------------------------------------------------------+"
echo "To put the Jetson-TX1 into recovery mode, hold REC and press the RST button"
read -p "Press [enter] button when ready"

# Get NVidia L4T tarball (Called "Driver Package" on the download site)

wget http://developer.download.nvidia.com/embedded/L4T/r23_Release_v1.0/Tegra210_Linux_R23.1.1_armhf.tbz2
echo "Extracting..."
tar -xf Tegra210_Linux_R23.1.1_armhf.tbz2

# Obtain Baserock image

#wget https://download.baserock.com/something/build-system-armv8l64-jetson-tx1.img.gz
#gunzip build-system-armv8l64-jetson-tx1.img.gz

# Mount image and copy boot files

mkdir /tmp/tx1mnt; sudo mount build-system-armv8l64-jetson-tx1.img /tmp/tx1mnt
sudo cp -R /tmp/tx1mnt/systems/factory/orig/boot .
cp /tmp/tx1mnt/extlinux.conf .
sudo umount /tmp/tx1mnt; rmdir /tmp/tx1mnt

# Copy Baserock files to flashing directories

cp -v boot/u-boot{,.bin,.dtb,-dtb.bin} Linux_for_Tegra/bootloader/t210ref/p2371-2180/
cp -v boot/Image Linux_for_Tegra/kernel/
cp -v boot/tegra210-p2371-2180.dtb Linux_for_Tegra/bootloader/t210ref/p2371-2180/

# U-Boot doesn't seem to see these at this path:
#mkdir -p Linux_for_Tegra/rootfs/systems/default
#cp -v boot/Image Linux_for_Tegra/rootfs/systems/default/kernel
#cp -v boot/tegra210-p2371-2180.dtb Linux_for_Tegra/rootfs/systems/default/dtb

# Quick fix for now:
cp -v boot/Image Linux_for_Tegra/rootfs/boot/kernel
cp -v boot/tegra210-p2371-2180.dtb Linux_for_Tegra/rootfs/boot/dtb
sed -i 's@systems/default/kernel@boot/kernel@' extlinux.conf
sed -i 's@systems/default/dtb@boot/dtb@' extlinux.conf

cp -v extlinux.conf Linux_for_Tegra/bootloader/t210ref/p2371-2180/extlinux.conf.emmc

# Modify L4T flasher settings

sed -i 's/EMMCSIZE=31276924928;/EMMCSIZE=15032385536;/' Linux_for_Tegra/p2371-2180.conf
sed -i 's/ROOTFSSIZE=14GiB/ROOTFSSIZE=128MiB/' Linux_for_Tegra/p2371-2180.conf
patch -p 0 << EOF
--- ./Linux_for_Tegra/bootloader/t210ref/cfg/gnu_linux_tegraboot_emmc_full.xml
+++ ./Linux_for_Tegra/bootloader/t210ref/cfg/gnu_linux_tegraboot_emmc_full.xml
@@ -219,13 +219,24 @@
         <partition name="UDA" id="23" type="data">
             <allocation_policy> sequential </allocation_policy>
             <filesystem_type> basic </filesystem_type>
+            <size> 10737418240 </size>
+            <file_system_attribute> 0 </file_system_attribute>
+            <allocation_attribute> 0x8 </allocation_attribute>
+            <partition_attribute> 0 </partition_attribute>
+            <percent_reserved> 0 </percent_reserved>
+            <filename> build-system-armv8l64-jetson-tx1.img </filename>
+        </partition>
+
+        <partition name="FREE" id="24" type="data">
+            <allocation_policy> sequential </allocation_policy>
+            <filesystem_type> basic </filesystem_type>
             <size> 2097152 </size>
             <file_system_attribute> 0 </file_system_attribute>
             <allocation_attribute> 0x808 </allocation_attribute>
             <percent_reserved> 0 </percent_reserved>
         </partition>
 
-        <partition name="GPT" id="24" type="GPT">
+        <partition name="GPT" id="25" type="GPT">
             <allocation_policy> sequential </allocation_policy>
             <filesystem_type> basic </filesystem_type>
             <size> 0xFFFFFFFFFFFFFFFF </size>
EOF

# Place rootfs image

mv build-system-armv8l64-jetson-tx1.img Linux_for_Tegra/bootloader

# Flash

read -p "Finished setting up, press [enter] to flash, ^C to exit."
cd Linux_for_Tegra/
sudo ./flash.sh p2371-2180 mmcblk0p1
