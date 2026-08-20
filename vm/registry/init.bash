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
        --domain-name) domain_name="$2";  shift 2 ;;
        --ip-address) ip_address="$2"; shift 2 ;;
        --help) echo "Usage: $0 --instance-id <id> --domain-name <name> --ip-address <ip>"; exit 0 ;;
        *) echo "Unknown option $1"; exit 1 ;;
    esac
done

if [[ -z "$ip_address" ]]; then
    echo "[error] --ip-address must be set in .env"
    exit 1
fi

export DOMAIN_NAME=${domain_name:-"harbor-1"}
export INSTANCE_ID=${instance_id:-$DOMAIN_NAME}
export DOMAIN_IP_ADDRESS=${ip_address}

###############MENU###############

# base directory to load user/meta data
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/../_scripts/load-env.bash"

# >>>> Following content will be used by cloud-init to fill the vm configuration >>>>
envsubst < "$DIR/conf/harbor.yml" > "/tmp/$DOMAIN_NAME.harbor.yml"
export HARBOR_CONFIG=$(base64 /tmp/$DOMAIN_NAME.harbor.yml -w 0)
export HARBOR_SERVICE=$(base64 "$DIR/conf/harbor.service" -w 0)
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

qemu-img create -f qcow2 -F qcow2 \
  -b /var/lib/libvirt/images/debian-13-generic-amd64.qcow2 \
  "/var/lib/libvirt/images/$DOMAIN_NAME-debian-13-generic-amd64.qcow2" 40G

virt-install \
  --name "$DOMAIN_NAME" \
  --memory 3000 \
  --vcpus 2 \
  --disk "/var/lib/libvirt/images/$DOMAIN_NAME-debian-13-generic-amd64.qcow2" \
  --disk "/var/lib/libvirt/images/$DOMAIN_NAME.iso,device=cdrom" \
  --network network=default \
  --os-variant debian13 \
  --import \
  --graphics vnc \
  --console pty,target_type=serial \
  --noautoconsole

echo "[virt] done !"
echo "[virt] domain has been defined and is now running..."
virsh list | grep "$DOMAIN_NAME"