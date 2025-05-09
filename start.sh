#!/bin/bash

show_help() {
    echo "Usage : $0 -h <hostname> -o <override> -r <rootsize> -m <mirror>"
    echo "Options :"
    echo "  -h <hostname>   Hostname of the target (mandatory)"
    echo "  -o <override>   Override of network (mandatory, 0 for none)"
    echo "  -r <rootsize>   Size of the root partition (mandatory)"
    echo "  -m <mirror>     Mirror (mandatory, use an IP if override is set)"
    echo "  -d <directory>  Directory for the space that will remain (mandatory)"
    exit 1
}

while getopts "h:o:r:m:d:" flag
do
    case "${flag}" in
        h) hostname=${OPTARG};;
        o) override=${OPTARG};;
        r) rootsize=${OPTARG};;
        m) mirror=${OPTARG};;
        d) directory=${OPTARG};;
        \?) echo "Invalid option : -$OPTARG" >&2
            show_help
            ;;
    esac
done

if [ -z "$hostname" ] || [ -z "$override" ] || [ -z "$rootsize" ] || [ -z "$mirror" ] || [ -z "$directory" ]; then
    echo "Missing options."
    show_help
fi

source vars.sh
mkdir /boot/debian-bookworm && cd "$_" || exit

### Preseed-only vars

base_url="http://${mirror}"
scsimod=$(curl -s "${base_url}"/debian/dists/bookworm/main/installer-amd64/current/images/udeb.list | grep scsi-modules | cut -d ' ' -f1)
files=("linux" "initrd.gz")
crypted=$(mkpasswd -m sha-512 -S $(pwgen -ns 16 1) "$password")

### Workarounds

# Some providers are using systemd-resolved, some not...
if [ "$dns" == "127.0.0.53" ];
then
dns=$(grep -w "DNS" /etc/systemd/resolved.conf | grep -v "\#" | cut -d '=' -f2 | awk '{ print $1 }')
fi

# Many images out there, with altnames... or not. WIP: improve the interface variable.
if [[ "$gateway" =~ "172.31" ]] || [[ "$HOSTNAME" == "template" ]];
then
checkinterface=$(ip addr | grep altname | tail -1 | awk '{ print $2 }')
if [ -n "$checkinterface" ];
then
interface=${checkinterface}
fi
fi

if [ "$override" != "0" ];
then
type=""
debconfgateway="none"
cat <<- EOF > preseed.cfg
d-i netcfg/enable boolean false
EOF

# Ugly hack that prevents d-i to configure the network by itself, using /sbin/ip. Keeping the old /sbin/ip for diag purposes and exiting gracefully when used by d-i.
earlycheck="sh -c 'ip link set dev $interface up ; ip addr add $link dev $interface ; ip route add $gateway dev $interface; ip route add default via $gateway dev $interface; mv /sbin/ip /sbin/ip2 ; echo exit 0 > /sbin/ip'"
# Refer to earlycheck's comment. Might be a better way to have a static config in an override scenario.
latecommand="; echo auto $interface >> /etc/network/interfaces ; echo iface $interface inet static >> /etc/network/interfaces ; echo address $ip >> /etc/network/interfaces ; echo netmask $netmask >> /etc/network/interfaces ; echo gateway $gateway >> /etc/network/interfaces ; echo nameserver 8.8.8.8 > /etc/resolv.conf'"

else
debconfgateway=$gateway
earlycheck="exit 0"
type="string"
latecommand="'"
fi

# When booting files are elsewhere
grep -q "/boot" /boot/grub/grub.cfg
if [ $? -eq 1 ];
then
bootpart="/"
else
bootpart="/boot/"
fi

cat <<- EOF >> preseed.cfg
d-i anna/choose_modules_lowmem multiselect partman-auto, $scsimod
d-i apt-setup/services-select multiselect security, updates
d-i apt-setup/security_path string /debian-security
d-i apt-setup/security_host string $mirror
d-i apt-setup/services-select multiselect security, updates
d-i apt-setup/security_path string /debian-security
d-i base-installer/kernel/image string linux-image-amd64
d-i base-installer/install-recommends boolean false
d-i clock-setup/utc boolean true
d-i clock-setup/ntp boolean true
d-i clock-setup/ntp-server string 0.debian.pool.ntp.org
d-i debian-installer/language string en
d-i debian-installer/country string US
d-i debian-installer/locale string en_US.UTF-8
d-i debian-installer/allow_unauthenticated boolean true
d-i finish-install/reboot_in_progress note
d-i grub-installer/bootdev string default
d-i grub-installer/force-efi-extra-removable boolean true
d-i hw-detect/load_firmware boolean false
d-i keyboard-configuration/xkb-keymap select us
d-i lowmem/low boolean true
d-i mirror/country string manual
d-i mirror/protocol string http
d-i mirror/http/hostname string $mirror
d-i mirror/http/directory string /debian
d-i mirror/http/proxy string
d-i mirror/suite string bookworm
d-i netcfg/choose_interface select auto
d-i netcfg/disable_autoconfig boolean true
d-i netcfg/get_ipaddress string $ip
d-i netcfg/get_netmask string $netmask
d-i netcfg/get_gateway $type $debconfgateway
d-i netcfg/get_nameservers string $dns
d-i netcfg/confirm_static boolean true
d-i netcfg/get_hostname string $hostname
d-i netcfg/get_domain string
d-i partman-auto/expert_recipe  string  naive :: $rootsize $rootsize $rootsize ext4 $primary{ } $bootable{ } method{ format } format{ } use_filesystem{ } filesystem{ ext4 } mountpoint{ / } . 10 10 10 linux-swap method{ swap } format{ } . 64 1000 -1 ext4 method{ format } format{ } use_filesystem{ } filesystem{ ext4 } $defaultignore{ } mountpoint{ $directory } .
d-i partman-auto/method string regular
d-i partman/early_command string debconf-set partman-auto/disk "\$(list-devices disk | head -n 1)"
d-i partman-partitioning/choose_label string gpt
d-i partman-partitioning/default_label string gpt
d-i partman/default_filesystem string ext4 .
d-i partman-basicmethods/method_only boolean false
d-i partman-auto/choose_recipe select naive
d-i partman-basicfilesystems/no_swap boolean false
d-i partman-partitioning/confirm_write_new_label boolean true
d-i partman/choose_partition select finish
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true
d-i partman-md/device_remove_md boolean true
d-i partman-lvm/device_remove_lvm boolean true
d-i partman-lvm/confirm_nooverwrite boolean true
d-i passwd/root-login boolean true
d-i passwd/make-user boolean false
d-i passwd/root-password-crypted password $crypted
d-i pkgsel/upgrade select full-upgrade
d-i preseed/late_command string \
in-target sh -c 'sed -Ei "s/^#?PermitRootLogin .+/PermitRootLogin yes/" /etc/ssh/sshd_config'; \
in-target sed -i 's/quiet/& apparmor=0/' /etc/default/grub; \
in-target grub-mkconfig -o /boot/grub/grub.cfg; \
in-target sh -c 'echo $hostname > /etc/hostname $latecommand
d-i preseed/early_command string $earlycheck
d-i time/zone string UTC
popularity-contest popularity-contest/participate boolean false
tasksel tasksel/first multiselect ssh-server
EOF

for file in "${files[@]}"; do
  until curl -sLO "$base_url/debian/dists/bookworm/main/installer-amd64/current/images/netboot/debian-installer/amd64/$file"; do
    echo "Retrying..."
    rm "$file"
    sleep 5
  done
done

gzip -d initrd.gz
echo preseed.cfg | cpio -o -H newc -A -F initrd
gzip -1 initrd

cat <<- EOF > /etc/default/grub
GRUB_DEFAULT=debonair
GRUB_TIMEOUT=1
GRUB_TIMEOUT_STYLE=menu
EOF

update-grub

cat <<- EOF >> /boot/grub/grub.cfg
menuentry 'Debonair automatic installer' --id debonair {
    insmod part_msdos
    insmod part_gpt
    insmod ext2
    insmod xfs
    insmod btrfs
    linux ${bootpart}debian-bookworm/linux lowmem/low=1
    initrd ${bootpart}debian-bookworm/initrd.gz
}
EOF
