#!/bin/bash
set -e
if [[ $EUID -ne 0 ]]; then
    echo "Ce script doit être lancé en root"
    exit 1
fi

###############MENU###############
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
set -a
source "$DIR/../../.env"
set +a

if [[ -z "$OPNSENSE_ADMIN_PASSWORD" ]]; then
    echo "[error] OPNSENSE_ADMIN_PASSWORD must be set in .env"
    exit 1
fi

if [[ -z "$VNC_PASSWORD" ]]; then
    echo "[error] VNC_PASSWORD must be set in .env"
    exit 1
fi
###############MENU###############

set +e
bzip2 2>/dev/null
rc=$?
set -e
if [[ $rc -eq 127 ]]; then
    echo "installing bunzip to unzip the opnsense package"
    apt update && apt install bzip2
fi

set +e
expect -v &>/dev/null
rc=$?
set -e
if [[ $rc -eq 127 ]]; then
    echo "[opnsense] installing expect to auto-answer the console setup"
    apt update && apt install -y expect
fi

set +e
genisoimage --version &>/dev/null
rc=$?
set -e
if [[ $rc -eq 127 ]]; then
    echo "installing genisoimage to build the config seed ISO"
    apt update && apt install genisoimage
fi

# the "dvd" ISO's installer only has a getty on the video console, not serial;
# the "serial" image is the same live/install media with a working serial
# console instead — still needs bsdinstall run against a separate target disk
if [[ ! -f "/var/lib/libvirt/images/OPNsense-26.7-serial-amd64.img" ]]; then
    echo "[net] downloading the OPNsense serial disk image — this needs internet access,"
    echo "      run this BEFORE applying netplan if enp1s0f0 is about to lose its"
    echo "      own IP (host has no other path out once bridged into br-wan)"
    wget -O /var/lib/libvirt/images/OPNsense-26.7-serial-amd64.img.bz2 \
        'https://pkg.opnsense.org/releases/26.7/OPNsense-26.7-serial-amd64.img.bz2'
    bunzip2 /var/lib/libvirt/images/OPNsense-26.7-serial-amd64.img.bz2
fi

# https://github.com/opnsense/core/issues/5733#issuecomment-2119130729
# >>>> build the config seed ISO for the OPNsense Configuration Importer >>>>
rm -rf /tmp/opnsense-config-iso
mkdir -p /tmp/opnsense-config-iso/conf
envsubst < "$DIR/conf/config.xml.tpl" > /tmp/opnsense-config-iso/conf/config.xml
genisoimage -o /var/lib/libvirt/images/opnsense-config.iso -V "CONFIG" -J -R /tmp/opnsense-config-iso
# <<<< build the config seed ISO for the OPNsense Configuration Importer <<<<

source "$DIR/../bridge/br-server.bash"

sudo virt-install \
  --name opnsense \
  --ram 4096 \
  --vcpus 2 \
  --os-variant freebsd14.0 \
  --disk /var/lib/libvirt/images/OPNsense-26.7-serial-amd64.img,format=raw,bus=sata \
  --disk pool=default,size=20,format=qcow2,bus=virtio \
  --disk /var/lib/libvirt/images/opnsense-config.iso,device=cdrom,bus=sata \
  --network bridge=br-wan,model=virtio,mac=0c:c4:7a:85:82:66 \
  --network bridge=br-user,virtualport_type=openvswitch,model=virtio \
  --network bridge=br-admin,virtualport_type=openvswitch,model=virtio \
  --network bridge=br-server,virtualport_type=openvswitch,model=virtio \
  --network bridge=br-dmz,virtualport_type=openvswitch,model=virtio \
  --graphics vnc,password="$VNC_PASSWORD" \
  --console pty,target_type=serial \
  --rng /dev/urandom,model=virtio \
  --boot uefi \
  --import \
  --noautoconsole

br_server_set_vlan opnsense 10,20,30,40
