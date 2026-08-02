#!/bin/bash

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
        --help) echo "Usage: $0 swarm_mode <mode> --instance-id <id> --domain-name <name>"; exit 0 ;;
        *) echo "Unknown option $1"; exit 1 ;;
    esac                                       
done
###############MENU###############

swarm_mode=${swarm_mode:-"manager"}
domain_name=${domain_name:-"swarm-1"}
instance_id=${instance_id:-$domain_name}
# base directory to load user/meta data
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$DIR/../load-env.bash"

# depending on mode, the user/meta data would differr
case $swarm_mode in
    "worker") DIR="${DIR}/worker" ;;
    "manager") DIR="${DIR}/manager" ;;
    *) echo "mode should be either worker or manager" ; exit 1 ;;
esac

cp "$DIR/meta-data.yml" "/tmp/$domain_name.meta-data.yml"

sed -i "s|{instance-id}|$instance_id|" "/tmp/$domain_name.meta-data.yml"
sed -i "s|{domain-name}|$domain_name|" "/tmp/$domain_name.meta-data.yml"

echo "[cloud-init] reading user-data and meta-data for $domain_name..."

envsubst < "$DIR/user-data.yml" > "/tmp/$domain_name.user-data.yml"

cloud-localds "/tmp/$domain_name.iso" "/tmp/$domain_name.user-data.yml" "/tmp/$domain_name.meta-data.yml"
cp "/tmp/$domain_name.iso" /var/lib/libvirt/images/

echo "[cloud-init] seed iso have been initialized at /tmp/$domain_name.iso..."

echo "[virt] installing the domain from cloud disk using seed instructions..."

if [[ ! -f /var/lib/libvirt/images/debian-13-generic-amd64.qcow2 ]]; then
    echo "[virt] need to download debian qemu disk"
    curl -L -o /var/lib/libvirt/images/debian-13-generic-amd64.qcow2 https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2
fi

echo "[virt] creating the disk for this vm based on debian 13"

sudo qemu-img create -f qcow2 -F qcow2 \
  -b /var/lib/libvirt/images/debian-13-generic-amd64.qcow2 \
  /var/lib/libvirt/images/$domain_name-debian-13-generic-amd64.qcow2 20G

virt-install \
  --name $domain_name \
  --memory 4000 \
  --vcpus 2 \
  --disk /var/lib/libvirt/images/$domain_name-debian-13-generic-amd64.qcow2 \
  --disk /tmp/$domain_name.iso,device=cdrom \
  --network network=default \
  --os-variant debian13 \
  --import \
  --graphics vnc \
  --noautoconsole

echo "[virt] done !"
echo "[virt] domain has been defined and is now running..."
virsh list | grep "$domain_name"