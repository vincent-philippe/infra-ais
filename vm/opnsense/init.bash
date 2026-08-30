#!/bin/bash
set -e
if [[ $EUID -ne 0 ]]; then
    echo "Ce script doit être lancé en root"
    exit 1
fi

###############MENU###############
while [[ $# -gt 0 ]]; do
    case $1 in
        --swarm-vip-address) swarm_vip_address="$2"; shift 2 ;;
        --help) echo "Usage: $0 --swarm-vip-address <ip>"; exit 0 ;;
        *) echo "Unknown option $1"; exit 1 ;;
    esac
done

if [[ -z "$swarm_vip_address" ]]; then
    echo "[error] --swarm-vip-address must be set"
    exit 1
fi

export SWARM_VIP_ADDRESS="$swarm_vip_address"

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
set -a
source "$DIR/../../.env"
set +a

if [[ -z "$OPNSENSE_ADMIN_PASSWORD" ]]; then
    echo "[error] OPNSENSE_ADMIN_PASSWORD must be set in .env"
    exit 1
fi
###############MENU###############

set +e
bzip2 2>/dev/null
set -e
if [[ $? -eq 127  ]]; then
    echo "installing bunzip to unzip the opnsense package"
    apt update && apt install bzip2
fi

set +e
genisoimage --version &>/dev/null
set -e
if [[ $? -eq 127 ]]; then
    echo "installing genisoimage to build the config seed ISO"
    apt update && apt install genisoimage
fi

if [[ ! -f "/var/lib/libvirt/images/OPNsense-26.7-dvd-amd64.iso" ]]; then
    echo "[net] downloading the OPNsense install ISO — this needs internet access,"
    echo "      run this BEFORE applying netplan if enp1s0f0 is about to lose its"
    echo "      own IP (host has no other path out once bridged into br-wan)"
    wget -O /var/lib/libvirt/images/OPNsense-26.7-dvd-amd64.iso.bz2 \
        'https://pkg.opnsense.org/releases/26.7/OPNsense-26.7-dvd-amd64.iso.bz2'
    bunzip2 /var/lib/libvirt/images/OPNsense-26.7-dvd-amd64.iso.bz2
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
  --disk pool=default,size=20,format=qcow2,bus=virtio \
  --cdrom /var/lib/libvirt/images/OPNsense-26.7-dvd-amd64.iso \
  --disk /var/lib/libvirt/images/opnsense-config.iso,device=cdrom,bus=sata \
  --network bridge=br-wan,model=virtio,mac=0c:c4:7a:85:82:66 \
  --network bridge=br-user,model=virtio \
  --network bridge=br-admin,model=virtio \
  --network bridge=br-server,virtualport_type=openvswitch,model=virtio \
  --network bridge=br-dmz,model=virtio \
  --graphics vnc,listen=0.0.0.0,port=5910 \
  --boot uefi \
  --noautoconsole

br_server_set_vlan opnsense 10,20,30