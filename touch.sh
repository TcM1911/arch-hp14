#!/bin/bash
# Modified for Arch Linux from ChrUbuntu's cros-haswell-modules.sh
# for kernel 3.14

set -e

# Determine kernel version
archkernver=$(uname -r)
kernver=$(uname -r | cut -d'-' -f 1)

# Install necessary deps to build a kernel
echo "Installing linux-headers..."
sudo pacman -S --needed linux-headers

# Grab kernel source
echo "Fetching kernel sources..."
wget https://www.kernel.org/pub/linux/kernel/v3.x/linux-${kernver}.tar.gz
echo "Extracting kernel sources..."
tar xfvz linux-${kernver}.tar.gz
cd linux-${kernver}

# Use Benson Leung's post-Pixel Chromebook patches: # 3074391 3074441 3074421
# https://patchwork.kernel.org/bundle/bleung/chromeos-laptop-deferring-and-haswell/ # 3078491 3078481 3074391 3074441 3074421 3074401 3074431 3074411
echo "Applying Chromebook Haswell Patches..."
#for patch in 3078491 3078481 3074401 3074431 3074411; do
for patch in 3074401 3074431 3074411; do
  wget -O - https://patchwork.kernel.org/patch/$patch/raw/ | sed 's/drivers\/platform\/x86\/chromeos_laptop.c/drivers\/platform\/chrome\/chromeos_laptop.c/g'| patch -p1
done

patch -p1 < ../i2c-designware-pcidrv.patch
wget -O - https://bugs.freedesktop.org/attachment.cgi?id=101813 | patch -p1

# fetch the chromeos_laptop and atmel maxtouch source code
# Copy made from chromium.googlesource.com chromeos-3.8 branch
# https://chromium.googlesource.com/chromiumos/third_party/kernel-next/+/refs/heads/chromeos-3.8
wget https://googledrive.com/host/0BxMvXgjEztvAbEdYM1o0ck5rOVE --output-document=patch_atmel_mxt_ts.c
wget https://googledrive.com/host/0BxMvXgjEztvAdVBjQUljYWtiR2c --output-document=patch_chromeos_laptop.c

# copy source files into kernel tree replacing existing Ubuntu source
#cp ./patch_atmel_mxt_ts.c drivers/input/touchscreen/atmel_mxt_ts.c
sed -e 's/INIT_COMPLETION(/reinit_completion(\&/g' ./patch_atmel_mxt_ts.c > drivers/input/touchscreen/atmel_mxt_ts.c
cp ./patch_chromeos_laptop.c drivers/platform/chrome/chromeos_laptop.c


# Need this
cp /usr/lib/modules/${archkernver}/build/Module.symvers .

# Prep tree
zcat /proc/config.gz > ./.config
make oldconfig
make prepare
make modules_prepare

echo "Building relevant modules..."
# Build only the needed directories
make SUBDIRS=drivers/platform/chrome modules
make SUBDIRS=drivers/i2c/busses modules
make SUBDIRS=drivers/input/touchscreen modules
make SUBDIRS=drivers/gpu/drm/i915 modules

echo "Installing relevant modules..."
# switch to using our new chromeos_laptop.ko module
# preserve old as .orig
chros_lap='/lib/modules/$archkernver/kernel/drivers/platform/chrome/chromeos_laptop.ko.gz'
if [ -f $chros_lap ];
then
sudo mv  $chros_lap ${chros_lap}.orig
fi
sudo cp drivers/platform/chrome/chromeos_laptop.ko /lib/modules/$archkernver/kernel/drivers/platform/chrome/
sudo gzip /lib/modules/$archkernver/kernel/drivers/platform/chrome/chromeos_laptop.ko

# switch to using our new designware i2c modules
# preserve old as .orig
sudo mv /lib/modules/$archkernver/kernel/drivers/i2c/busses/i2c-designware-core.ko.gz /lib/modules/$archkernver/kernel/drivers/i2c/busses/i2c-designware-core.ko.gz.orig
sudo mv /lib/modules/$archkernver/kernel/drivers/i2c/busses/i2c-designware-pci.ko.gz /lib/modules/$archkernver/kernel/drivers/i2c/busses/i2c-designware-pci.ko.gz.orig
sudo cp drivers/i2c/busses/i2c-designware-*.ko /lib/modules/$archkernver/kernel/drivers/i2c/busses/
sudo gzip /lib/modules/$archkernver/kernel/drivers/i2c/busses/i2c-designware-*.ko

# switch to using our new atmel_mxt_ts.ko module
# preserve old as .orig
sudo mv /lib/modules/$archkernver/kernel/drivers/input/touchscreen/atmel_mxt_ts.ko.gz /lib/modules/$archkernver/kernel/drivers/input/touchscreen/atmel_mxt_ts.ko.gz.orig
sudo cp drivers/input/touchscreen/atmel_mxt_ts.ko /lib/modules/$archkernver/kernel/drivers/input/touchscreen/
sudo gzip /lib/modules/$archkernver/kernel/drivers/input/touchscreen/atmel_mxt_ts.ko
sudo mv /lib/modules/$archkernver/kernel/drivers/gpu/drm/i915/i915.ko.gz /lib/modules/$archkernver/kernel/drivers/gpu/drm/i915/i915.ko.gz.orig
sudo cp drivers/gpu/drm/i915/i915.ko /lib/modules/$archkernver/kernel/drivers/gpu/drm/i915/i915.ko
sudo gzip /lib/modules/$archkernver/kernel/drivers/gpu/drm/i915/i915.ko

sudo depmod -a $archkernver

echo "Installing xf86-input-synaptics..."
sudo pacman -S --needed xf86-input-synaptics

echo "Reboot to use your touchpad!"
