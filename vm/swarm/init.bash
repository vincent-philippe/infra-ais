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
        --swarm-mode) swarm_mode="$2"; shift 2 ;;
        --help) echo "Usage: $0 swarm-mode <mode> --instance-id <id> --domain-name <name>"; exit 0 ;;
        *) echo "Unknown option $1"; exit 1 ;;
    esac                                       
done

swarm_mode=${swarm_mode:-"manager"}
domain_name=${domain_name:-"swarm-1"}
instance_id=${instance_id:-$domain_name}
###############MENU###############

# base directory to load user/meta data
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# depending on mode, the user/meta data would differr
case $swarm_mode in
    "worker") DIR="${DIR}/worker" ;;
    "manager") DIR="${DIR}/manager" ;;
    *) echo "mode should be either worker or manager" ; exit 1 ;;
esac

source "$DIR/../../_scripts/load-env.bash"
source "$DIR/../../_scripts/boot-cloud-init.bash"

if virsh dominfo "$domain_name" &>/dev/null; then
    echo "[virt] Le domaine '$domain_name' est déjà défini dans virsh, abandon."
    exit 1
fi

if [[ ! -f /var/lib/libvirt/images/debian-13-generic-amd64.qcow2 ]]; then
    echo "[virt] need to download debian qemu disk"
    curl -L -o /var/lib/libvirt/images/debian-13-generic-amd64.qcow2 https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2
fi

echo "[virt] creating the disk for this vm based on debian 13"

qemu-img create -f qcow2 -F qcow2 \
  -b /var/lib/libvirt/images/debian-13-generic-amd64.qcow2 \
  "/var/lib/libvirt/images/$domain_name-debian-13-generic-amd64.qcow2" 20G

virt-install \
  --name "$domain_name" \
  --memory 4000 \
  --vcpus 2 \
  --disk "/var/lib/libvirt/images/$domain_name-debian-13-generic-amd64.qcow2" \
  --disk "/var/lib/libvirt/images/$domain_name.iso,device=cdrom" \
  --network network=default \
  --os-variant debian13 \
  --import \
  --graphics vnc \
  --noautoconsole

echo "[virt] done !"
echo "[virt] domain has been defined and is now running..."
virsh list | grep "$domain_name"