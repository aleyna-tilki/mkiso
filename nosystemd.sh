#!/bin/bash
apt update
# Block service invoke
echo -e  "#!/bin/sh\nexit 101" > /usr/sbin/policy-rc.d
chmod +x /usr/sbin/policy-rc.d
# Remove systemd preremove script.
rm -f /var/lib/dpkg/info/systemd.prerm
# Install openrc and elogind (if you want use sysv-rc instead of openrc)
apt install elogind sysvinit-core openrc systemd- systemd-sysv- -y --allow-remove-essential
apt-mark hold systemd libsystemd0 libsystemd-shared
apt install -f
apt full-upgrade -y
apt autoremove --purge -y
# create empty systemctl command for some hardcoded stuffs
ln -s /bin/true /bin/systemctl
# cleanup journal garbages
rm -rf /var/log/journal
