#!/bin/bash
set -e
if [[ $EUID -ne 0 ]]; then
    echo "Ce script doit être lancé en root"
    exit 1
fi

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

if [[ -z "/var/lib/libvirt/images/OPNsense-26.1-dvd-amd64.iso" ]]; then
    wget 'https://pkg.opnsense.org/releases/26.7/OPNsense-26.7-dvd-amd64.iso.bz2'
    bunzip2 OPNsense-26.1-dvd-amd64.iso.bz2
fi

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/../_scripts/load-env.bash"

if [[ -z "$SWARM_VIP_ADDRESS" ]]; then
    echo "[error] SWARM_VIP_ADDRESS must be set in .env"
    exit 1
fi

if [[ -z "$OPNSENSE_ADMIN_PASSWORD" ]]; then
    echo "[error] OPNSENSE_ADMIN_PASSWORD must be set in .env"
    exit 1
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
  --cdrom /var/lib/libvirt/images/OPNsense-26.1.2-dvd-amd64.iso \
  --disk /var/lib/libvirt/images/opnsense-config.iso,device=cdrom,bus=sata \
  --network=bridge:br-wan,model=virtio,mac=0c:c4:7a:85:82:66 \
  --network=bridge:br-user,model=virtio \
  --network=bridge:br-admin,model=virtio \
  --network bridge=br-server,virtualport_type=openvswitch,model=virtio,vlan.trunk=yes,vlan.tag0.id=10,vlan.tag1.id=20,vlan.tag2.id=30 \
  --network=bridge:br-dmz,model=virtio \
  --graphics vnc,listen=0.0.0.0,port=5910 \
  --boot uefi \
  --noautoconsole
