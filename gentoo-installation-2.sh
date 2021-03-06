#!/bin/bash

set -e

GENTOO_RELEASES_URL=http://distfiles.gentoo.org/releases

GENTOO_ARCH=amd64
GENTOO_VARIANT=amd64

TARGET_DISK=/dev/sda

PARTITION_BOOT_SIZE=128M
PARTITION_SWAP_SIZE=1G

USE_LIVECD_KERNEL=1

GRUB_PLATFORMS=pc

echo "### Configuring emerge..."

emerge-webrsync
eselect news read
eselect profile list
eselect profile set 20
emerge --ask --verbose --update --deep --newuse @world

echo "### Upading configuration..."

env-update && source /etc/profile

echo "### Installing kernel sources..."

emerge sys-kernel/gentoo-sources

if [ "$USE_LIVECD_KERNEL" = 0 ]; then
    echo "### Installing kernel..."
    echo "sys-apps/util-linux static-libs" > /etc/portage/package.use/genkernel
    emerge sys-kernel/genkernel
    genkernel all --kernel-config=/etc/kernels/kernel-config-*
fi
emerge --ask sys-kernel/linux-firmware
echo "### Installing bootloader..."

emerge grub

cat >> /etc/portage/make.conf << IEND

# added by gentoo installer

GRUB_PLATFORMS="$GRUB_PLATFORMS"
IEND
cat >> /etc/default/grub << IEND

# added by gentoo installer

GRUB_CMDLINE_LINUX="net.ifnames=0"
GRUB_DEFAULT=0
GRUB_TIMEOUT=0
IEND
grub-install ${TARGET_DISK}
grub-mkconfig -o /boot/grub/grub.cfg

echo "### Configuring network..."
emerge --ask app-admin/sysklogd
rc-update add sysklogd default
emerge --ask net-misc/dhcpcd
#ln -s /etc/init.d/net.lo /etc/init.d/net.eth0
#rc-update add net.eth0 default

#echo "### Configuring SSH..."

#rc-update add sshd default
#passwd -d -l root
#mkdir /root/.ssh
#touch /root/.ssh/authorized_keys
#chmod 750 /root/.ssh
#chmod 640 /root/.ssh/authorized_keys
#echo $SSH_PUBLIC_KEY > /root/.ssh/authorized_keys
#END
#chmod +x /mnt/gentoo/root/gentoo-init.sh
#chroot /mnt/gentoo /root/gentoo-init.sh

echo "### Cleaning..."
rm /mnt/gentoo/$(basename $STAGE3_URL)
rm /mnt/gentoo/$(basename $PORTAGE_URL)
rm /mnt/gentoo/root/gentoo-init.sh
echo "### Rebooting..."
passwd
# signal that installation is completed before rebooting
#for i in `seq 1 10`; do tput bel; done
#reboot
