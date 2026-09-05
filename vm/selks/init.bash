#!/bin/bash
set -e
if [[ $EUID -ne 0 ]]; then
    echo "Ce script doit être lancé en root"
    exit 1
fi

###############MENU###############
while [[ $# -gt 0 ]]; do
    case $1 in
        --instance-id) instance_id="$2"; shift 2 ;;
        --domain-name) domain_name="$2"; shift 2 ;;
        --ip-address) ip_address="$2"; shift 2 ;;
        --help) echo "Usage: $0 --domain-name <name> --ip-address <ip/cidr>"; exit 0 ;;
        *) echo "Unknown option $1"; exit 1 ;;
    esac
done

if [[ -z "$ip_address" ]]; then
    echo "[error] --ip-address must be set"
    exit 1
fi

export DOMAIN_NAME=${domain_name:-"selks-1"}
export INSTANCE_ID=${instance_id:-$DOMAIN_NAME}
export DOMAIN_IP_ADDRESS=${ip_address}
export DOMAIN_IP=${ip_address%%/*}

###############MENU###############

# base directory to load user/meta data
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/../_scripts/load-env.bash"

# >>>> Following content will be used by cloud-init to fill the vm configuration >>>>
envsubst < "$DIR/conf/selks.env" > "/tmp/$DOMAIN_NAME.selks.env"
export SELKS_ENV=$(base64 /tmp/$DOMAIN_NAME.selks.env -w 0)
export SELKS_SERVICE=$(base64 "$DIR/conf/selks.service" -w 0)
# <<<< Following content will be used by cloud-init to fill the vm configuration <<<<

source "$DIR/../_scripts/boot-cloud-init.bash"

if virsh dominfo "$DOMAIN_NAME" &>/dev/null; then
    echo "[virt] Le domaine '$DOMAIN_NAME' est déjà défini dans virsh, abandon."
    exit 1
fi

if [[ ! -f /var/lib/libvirt/images/debian-13-generic-amd64.qcow2 ]]; then
    echo "[virt] need to download debian qemu disk"
    curl -L -o /var/lib/libvirt/images/debian-13-generic-amd64.qcow2 https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2
fi

echo "[virt] creating the disk for this vm based on debian 13"

# SELKS/Elasticsearch needs real log storage (Suricata eve logs + ES indices)
qemu-img create -f qcow2 -F qcow2 \
  -b /var/lib/libvirt/images/debian-13-generic-amd64.qcow2 \
  "/var/lib/libvirt/images/$DOMAIN_NAME-debian-13-generic-amd64.qcow2" 60G

source "$DIR/../bridge/br-server.bash"
source "$DIR/../bridge/br-mirror.bash"

SELKS_MGMT_MAC="52:54:00:be:ef:01"
SELKS_MIRROR_MAC="52:54:00:be:ef:02"

virt-install \
  --name "$DOMAIN_NAME" \
  --memory 12216 \
  --vcpus 4 \
  --disk "/var/lib/libvirt/images/$DOMAIN_NAME-debian-13-generic-amd64.qcow2" \
  --disk "/var/lib/libvirt/images/$DOMAIN_NAME.iso,device=cdrom" \
  --network bridge=br-server,virtualport_type=openvswitch,mac="$SELKS_MGMT_MAC" \
  --network bridge=br-user,virtualport_type=openvswitch \
  --network bridge=br-admin,virtualport_type=openvswitch \
  --network bridge=br-dmz,virtualport_type=openvswitch \
  --network bridge=br-server,virtualport_type=openvswitch,mac="$SELKS_MIRROR_MAC" \
  --os-variant debian13 \
  --import \
  --graphics vnc,password="$VNC_PASSWORD" \
  --console pty,target_type=serial \
  --noautoconsole

br_server_set_vlan "$DOMAIN_NAME" 40 "$SELKS_MGMT_MAC"
br_set_mirror "$DOMAIN_NAME" br-user
br_set_mirror "$DOMAIN_NAME" br-admin
br_set_mirror "$DOMAIN_NAME" br-dmz
br_set_mirror "$DOMAIN_NAME" br-server "$SELKS_MIRROR_MAC"

echo "[virt] done !"
echo "[virt] domain has been defined and is now running..."
virsh list | grep "$DOMAIN_NAME"
