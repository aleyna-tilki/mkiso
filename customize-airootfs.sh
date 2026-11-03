#!/usr/bin/env bash
cd /tmp

### Instally 17g and other stuff
apt update
yes | apt install wget -yq
wget https://github.com/aleyna-tilki/base-files/releases/download/current/base-files_9999-noupdate_amd64.deb
wget https://github.com/aleyna-tilki/17g-installer/releases/download/current/17g-installer_1.0_all.deb
wget https://github.com/pardus-nosystemd/desktop-base/releases/download/current/desktop-base_9999-noupdate_all.deb
wget https://github.com/aleyna-tilki/aleyna-theme/releases/download/current/aleyna-theme_1.0_amd64.deb
wget https://github.com/aleyna-tilki/pipewire-launcher/releases/download/current/pipewire-launcher_1.0.0_all.deb
yes | apt install ./*.deb -yq --allow-downgrades

### hardened stuff
mkdir -p /etc/sysctl.d/
wget https://gitlab.com/turkmen-linux/devel/sources/base-files/-/raw/master/rootfs/etc/sysctl.d/990-security.conf -O /etc/sysctl.d/990-security.conf
echo "b08dfa6083e7567a1921a715000001fb" > /etc/machine-id
### module blacklists
for list in mei pmt webcam wmi ; do
    wget https://gitlab.com/turkman/devel/sources/base-files/-/raw/master/rootfs/etc/modprobe.d/${list}.conf -O /etc/modprobe.d/${list}.conf
done
## network manager settings
mkdir -p /etc/NetworkManager/conf.d/
cat > /etc/NetworkManager/conf.d/31-privacy.conf <<EOF
[device-mac-randomization]
wifi.scan-rand-mac-address=yes

[connection-mac-randomization]
ethernet.cloned-mac-address=random
wifi.cloned-mac-address=random

EOF

#### Disable recommends by default
cat > /etc/apt/apt.conf.d/01norecommend << EOF
APT::Install-Recommends "0";
APT::Install-Suggests "0";
EOF

# kernel parameters
cat > /etc/default/grub.d/31-console.cfg << EOF
GRUB_CMDLINE_LINUX_DEFAULT="console=tty31 \$GRUB_CMDLINE_LINUX_DEFAULT"
EOF

# remove all languages except turkish
cat > /etc/dpkg/dpkg.cfg.d/language-excludes << EOF
path-exclude=/usr/share/locale/*
path-exclude=/usr/share/man/*
path-exclude=/usr/share/help/*
path-exclude=/usr/share/doc/*
path-exclude=/usr/share/info/*

# Exclude Turkish and C
path-include=/usr/share/locale/tr*
path-include=/usr/share/locale/C*
EOF

rm -rf /usr/share/man/*
rm -rf /usr/share/help/*
rm -rf /usr/share/doc/*
rm -rf /usr/share/info/*

find /usr/share/locale/ -mindepth 1 -maxdepth 1 \
    ! -name 'tr' \
    ! -name 'tr_*' \
    ! -name 'C' \
    ! -name 'C.*' \
    ! -name 'POSIX' \
    -exec rm -rf {} +

