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

SSH_PUBLIC_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCS5o8WXoM+u0qZ/Yx0h+3SNDrSQYp0B5hT0yh4jw/wmTLWsQ5SSI8U7xLxv6EXR4uY9IeNdaz9+dxIPHQRoG3fnqhfY7R4YVZG5Jd5jO4MzIUJrlvfL8CPH19AAlOToiWPiQ5OiCGo7Qh3wmbcfhvWyz7leuAesqO5mJxZrYSNghJ16fdZ8ht7yYLjreO3TDlhmFcac6Bc3F0c29KIv4lSXHOg6rGhDpT3Ww80v9dzbxoC7LktuNwKVUPHs2ndQdRwdOqV7gUAVcXl+7XoFRcppNIzpoiQt5Ve9Z2RM8LEdfz+HZv1lhmDZKKN2SEcubmN1fI6q1x3wDoMxiyfqiD5"

echo "### Setting time..."

ntpd -gq

echo "### Creating partitions..."

sfdisk ${TARGET_DISK} << END
size=$PARTITION_BOOT_SIZE,bootable
size=$PARTITION_SWAP_SIZE
;
END

echo "### Formatting partitions..."

yes | mkfs.ext4 ${TARGET_DISK}1
yes | mkswap ${TARGET_DISK}2
yes | mkfs.ext4 ${TARGET_DISK}3

echo "### Labeling partitions..."

e2label ${TARGET_DISK}1 boot
swaplabel ${TARGET_DISK}2 -L swap
e2label ${TARGET_DISK}3 root

echo "### Mounting partitions..."

swapon ${TARGET_DISK}2

mkdir -p /mnt/gentoo
mount ${TARGET_DISK}3 /mnt/gentoo

mkdir -p /mnt/gentoo/boot
mount ${TARGET_DISK}1 /mnt/gentoo/boot

echo "### Setting work directory..."

cd /mnt/gentoo

echo "### Downloading stage3..."

STAGE3_PATH_URL=$GENTOO_RELEASES_URL/$GENTOO_ARCH/autobuilds/latest-stage3-$GENTOO_VARIANT.txt
STAGE3_PATH=$(curl -s $STAGE3_PATH_URL | grep -v "^#" | cut -d" " -f1)
STAGE3_URL=$GENTOO_RELEASES_URL/$GENTOO_ARCH/autobuilds/$STAGE3_PATH

wget $STAGE3_URL

echo "### Extracting stage3..."

tar xvpf $(basename $STAGE3_URL)

echo "### Downloading portage..."

PORTAGE_URL=$GENTOO_RELEASES_URL/snapshots/current/portage-latest.tar.xz
wget $PORTAGE_URL

echo "### Extracting portage..."

tar xvf $(basename $PORTAGE_URL) -C usr

if [ "$USE_LIVECD_KERNEL" != 0 ]; then
    echo "### Installing LiveCD kernel..."

    LIVECD_KERNEL_VERSION=$(cat /proc/version | cut -d" " -f3)
    KERNEL_ARCH_SUFFIX=$(echo $GENTOO_ARCH | sed "s/^amd64$/x86_64/")

    cp -v /mnt/cdrom/boot/gentoo \
        /mnt/gentoo/boot/kernel-genkernel-$KERNEL_ARCH_SUFFIX-$LIVECD_KERNEL_VERSION
    cp -v /mnt/cdrom/boot/gentoo.igz \
        /mnt/gentoo/boot/initramfs-genkernel-$KERNEL_ARCH_SUFFIX-$LIVECD_KERNEL_VERSION
    cp -vR /lib/modules/$LIVECD_KERNEL_VERSION /mnt/gentoo/lib/modules/
fi

echo "### Installing kernel configuration..."

mkdir -p /mnt/gentoo/etc/kernels
cp -v /etc/kernels/* /mnt/gentoo/etc/kernels

echo "### Initializing portage..."

mkdir -p /mnt/gentoo/etc/portage/repos.conf
cp /mnt/gentoo/usr/share/portage/config/repos.conf /mnt/gentoo/etc/portage/repos.conf/gentoo.conf

echo "### Copying network options..."

cp -v /etc/resolv.conf /mnt/gentoo/etc/

echo "### Configuring fstab..."

cat >> /mnt/gentoo/etc/fstab << END

# added by gentoo installer
LABEL=boot /boot ext4 noauto,noatime 1 2
LABEL=swap none  swap sw             0 0
LABEL=root /     ext4 noatime        0 1
END

echo "### Mounting proc/sys/dev/pts..."

#mount -t proc none /mnt/gentoo/proc
#mount -t sysfs none /mnt/gentoo/sys
#mount -o bind /dev /mnt/gentoo/dev
#mount -o bind /dev/pts /mnt/gentoo/dev/pts

mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev 

echo "### Changing root..."

chroot /mnt/gentoo /bin/bash
source /etc/profile
export PS1="(chroot) ${PS1}"

cat > /mnt/gentoo/root/gentoo-init.sh << END

emerge htop
