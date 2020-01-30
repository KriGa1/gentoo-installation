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
eselect news list
eselect news read
eselect profile list
eselect profile set 2
emerge --ask --verbose --update --deep --newuse @world
env-update && source /etc/profile && export PS1="(chroot) ${PS1}"

echo "### Configuring fstab..."

cat >> /mnt/gentoo/etc/fstab << END

# added by gentoo installer
LABEL=boot /boot ext4 noauto,noatime 1 2
LABEL=swap none  swap sw             0 0
LABEL=root /     ext4 noatime        0 1
END

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

ln -s /etc/init.d/net.lo /etc/init.d/net.eth0
rc-update add net.eth0 default

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
# signal that installation is completed before rebooting
#for i in `seq 1 10`; do tput bel; done
#reboot
