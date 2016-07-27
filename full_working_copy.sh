#!/bin/bash
LOCALDRIVE="/dev/sda"
USBDRIVE="/dev/sdc"
HOSTNAME = "xps13"
ROOTUUID = ""
BOOTUUID = ""

#### enable WIFI
wifi-manager

### make the font larger ###
setfont sun12x22

### set the keyboard ###
localectl set-keymap us

### partition the USBDRIVE ###
sgdisk -og $USBDRIVE
sgdisk -n 1:2048:4095 -c 1:"BIOS Boot Partition" -t 1:ef02 $USBDRIVE
sgdisk -n 2:4096:413695 -c 2:"EFI System Partition" -t 2:ef00 $USBDRIVE
sgdisk -n 3:413696:823295 -c 3:"Linux /boot" -t 3:8300 $USBDRIVE
ENDSECTOR=`sgdisk -E $USBDRIVE`
sgdisk -n 4:823296:$ENDSECTOR -c 4:"Linux LVM" -t 4:8e00 $USBDRIVE
sgdisk -p $USBDRIVE

### partition the SSD ###
sgdisk -og $LOCALDRIVE
sgdisk -n 1:0:0 -c 1:"Linux LVM" -t 1:8e00 $LOCALDRIVE
sgdisk -p $LOCALDRIVE

### create headers ###
truncate -s 2M bootheader.img

### crypt SSD LVM ###
cryptsetup -v --cipher aes-xts-plain64 --key-size 256 --hash sha256 --iter-time 3000 --use-random luksFormat "${LOCALDRIVE}1"
cryptsetup luksOpen "${LOCALDRIVE}1" lvm

### crypt USBDRIVE ###
cryptsetup -v --cipher aes-xts-plain64 --key-size 256 --hash sha256 --iter-time 3000 --use-random luksFormat "${USBDRIVE}2"
cryptsetup open --header bootheader.img --type luks "${USBDRIVE}2" cryptboot
mkfs.ext2 /dev/mapper/cryptboot
mkfs.fat -F32 "${USBDRIVE}1"

### make LVM partitions on SSD ###
pvcreate /dev/mapper/lvm
vgcreate vg /dev/mapper/lvm
lvcreate -L 8G vg -n swap
lvcreate -L 50G vg -n root
lvcreate -l +100%FREE vg -n home
swapon /dev/mapper/vg-swap
mkfs.ext4 /dev/mapper/vg-root
mkfs.ext4 /dev/mapper/vg-home

### mount all drives ###
mount /dev/mapper/vg-root /mnt
mkdir /mnt/home
mount /dev/mapper/vg-home /mnt/home
mkdir /mnt/boot
mount /dev/mapper/cryptboot /mnt/boot
mv bootheader.img /mnt/boot
mkdir /mnt/boot/efi
mount "${USBDRIVE}1" /mnt/boot/efi
lsblk

pacstrap /mnt base base-devel grub-efi-x86_64 zsh vim git efibootmgr dialog wpa_supplicant
genfstab -pU /mnt >> /mnt/etc/fstab

arch-chroot /mnt /bin/bash
ln -s /usr/share/zoneinfo/America/Chicago /etc/localtime
hwclock --systohc --utc
echo $HOSTNAME > /etc/hostname

echo LANG=en_US.UTF-8 >> /etc/locale.conf
echo LANGUAGE=en_US >> /etc/locale.conf
echo LC_ALL=C >> /etc/locale.conf

