#!/bin/bash
set -e
#### Check root
if [[ ! $UID -eq 0 ]] ; then
    echo -e "\033[31;1mYou must be root!\033[:0m"
    exit 1
fi
#### Remove all environmental variable
for e in $(env | sed "s/=.*//g") ; do
    unset "$e" &>/dev/null
done

#### Set environmental variables
export PATH=/bin:/usr/bin:/sbin:/usr/sbin
export LANG=C
export SHELL=/bin/bash
export TERM=linux
export DEBIAN_FRONTEND=noninteractive

#### Install dependencies
if which apt &>/dev/null && [[ -d /var/lib/dpkg && -d /etc/apt ]] ; then
    apt-get update
    apt-get install curl mtools squashfs-tools grub-pc-bin grub-efi-amd64-bin grub2-common grub-common grub-efi-ia32-bin xorriso debootstrap binutils -y --no-install-recommends
fi

set -ex
#### Chroot create
mkdir chroot || true

#### For debian
debootstrap --variant=minbase --arch=amd64 testing chroot
echo "deb https://deb.debian.org/debian testing main contrib non-free non-free-firmware" > chroot/etc/apt/sources.list
echo "deb http://deb.devuan.org/merged testing main contrib non-free non-free-firmware" >> chroot/etc/apt/sources.list

#### devuan
chroot chroot apt update  --allow-insecure-repositories
chroot chroot apt install devuan-keyring --allow-unauthenticated
chroot chroot apt update
chroot chroot apt full-upgrade -yq

#### Remove systemd
#cp nosystemd.sh chroot/tmp/nosystemd.sh
#chroot chroot bash -ex /tmp/nosystemd.sh
#rm chroot/tmp/nosystemd.sh

#### upgrade
chroot chroot apt update
chroot chroot apt full-upgrade -yq

#### Set root password
pass="live"
echo -e "$pass\n$pass\n" | chroot chroot passwd

#### Fix apt & bind
# apt sandbox user root
echo "APT::Sandbox::User root;" > chroot/etc/apt/apt.conf.d/99sandboxroot
for i in dev dev/pts proc sys; do mount -o bind /$i chroot/$i; done
chroot chroot apt-get install gnupg -y

#### grub packages
chroot chroot apt-get dist-upgrade -y
chroot chroot apt-get install grub-pc-bin grub-efi-ia32-bin grub-efi -y

#### live packages
chroot chroot apt-get install live-config live-config-sysvinit live-boot -y
echo "DISABLE_DM_VERITY=true" >> chroot/etc/live/boot.conf

#### customize
cp customize-airootfs.sh chroot/tmp/customize-airootfs.sh
chroot chroot bash -ex /tmp/customize-airootfs.sh
rm chroot/tmp/customize-airootfs.sh


# Set sh as bash inside of dash (optional)
rm -f chroot/bin/sh
ln -s bash chroot/bin/sh

#### kernel
chroot chroot apt-get install linux-image-amd64 -y
#chroot chroot apt-get install linux-headers-amd64 -y

#### xorg & desktop pkgs
chroot chroot apt-get install xserver-xorg xinit -y

#### Install packages
chroot chroot apt-get install $(cat packages.txt firmware.txt | grep -v '#'| tr "\n" " ") -y

#### Clear logs and history
chroot chroot apt-get clean
rm -f chroot/root/.bash_history
rm -rf chroot/var/lib/apt/lists/*
find chroot/var/log/ -type f | xargs rm -f

### create iso template
mkdir -p aleyna/boot || true
mkdir -p aleyna/live || true
ln -s live aleyna/casper || true

#### Copy kernel and initramfs (Debian/Devuan)
cp -pf chroot/boot/initrd.img-* aleyna/boot/initrd.img
cp -pf chroot/boot/vmlinuz-* aleyna/boot/vmlinuz

#### Remove initrd.img for minimize iso size (optional)
rm -rf chroot/boot/initrd.img-*

#### Create squashfs
for dir in dev dev/pts proc sys ; do
    while umount -lf -R chroot/$dir 2>/dev/null ; do true; done
done
# For better installation time
#mksquashfs chroot filesystem.squashfs -comp gzip -wildcards
# For better compress ratio
mksquashfs chroot filesystem.squashfs -comp xz -wildcards

### move squashfs file
mv filesystem.squashfs aleyna/live/filesystem.squashfs

#### Write grub.cfg
mkdir -p aleyna/boot/grub/
echo 'menuentry "Start Aleyna Tilki GNU/Linux 64-bit" --class aleyna {' > aleyna/boot/grub/grub.cfg
echo '    linux /boot/vmlinuz boot=live live-config quiet --' >> aleyna/boot/grub/grub.cfg
echo '    initrd /boot/initrd.img' >> aleyna/boot/grub/grub.cfg
echo '}' >> aleyna/boot/grub/grub.cfg

#### Create iso
grub-mkrescue aleyna -o aleyna-tilki-$(date +%s).iso
