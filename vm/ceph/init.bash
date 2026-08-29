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
        --ip-internal-address) ip_internal_address="$2"; shift 2 ;;
        --ip-address) ip_address="$2"; shift 2 ;;
        --ip-master) ip_master="$2"; shift 2 ;;
        --net-cluster) net_cluster="$2"; shift 2 ;;
        --help) echo 'Usage: $0 --instance-id <id> --domain-name <name> --ip-address <ip/cidr> [--ip-master <ip/cidr>|--net-cluster <ip/cidr>] --ip-internal-address <ip/cidr>'; exit 0 ;;
        *) echo "Unknown option $1"; exit 1 ;;
    esac
done

if [[ -z "$ip_address" ]]; then
    echo "[error] --ip-address must be set"
    exit 1
fi

export DOMAIN_NAME=${domain_name:-"ceph"}
export INSTANCE_ID=${instance_id:-$DOMAIN_NAME}
export DOMAIN_IP_ADDRESS=${ip_address}
export DOMAIN_IP=${ip_address%%/*}
export MASTER_IP_ADDRESS=${ip_master}
export MASTER_IP=${ip_master%%/*}
export IP_INTERNAL_CLUSTER=${ip_internal_address}
export CLUSTER_NETWORK=${net_cluster}

###############MENU###############

# base directory to load user/meta data
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$DIR/../_scripts/load-env.bash"

# if there's a master ip, then the new node is expected to be added to the cluster
if  [[ -z "$ip_master" ]]; then
    DIR="${DIR}/master"
else
    DIR="${DIR}/backup"
    export MASTER_SSH_PUB_KEY=$(ssh -q -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null admin@"$MASTER_IP" "cat /etc/ceph/ceph.pub" | base64 -w 0)
fi

# common directories (overriding default which is to pick from the subdirectories while in our case this is common files)
export DIR_META="${DIR}/.."
export DIR_NETWORK="${DIR}/.."

source "$DIR/../../_scripts/boot-cloud-init.bash"

if virsh dominfo "$DOMAIN_NAME" &>/dev/null; then
    echo "[virt] Le domaine '$DOMAIN_NAME' est déjà défini dans virsh, abandon."
    exit 1
fi

if [[ ! -f /var/lib/libvirt/images/debian-13-generic-amd64.qcow2 ]]; then
    echo "[virt] need to download debian qemu disk"
    curl -L -o /var/lib/libvirt/images/debian-13-generic-amd64.qcow2 https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2
fi

echo "[virt] creating the disk for this vm $DOMAIN_NAME based on debian 13"

qemu-img create -f qcow2 -F qcow2 \
  -b /var/lib/libvirt/images/debian-13-generic-amd64.qcow2 \
  "/var/lib/libvirt/images/$DOMAIN_NAME-debian-13-generic-amd64.qcow2" 20G

# Disque OSD dédié
qemu-img create -f qcow2 /var/lib/libvirt/images/$DOMAIN_NAME-osd.qcow2 300G

# Le bridge pour le network cluster (heartbeat -> synchro -> backup sur un réseau séparé)

if ! virsh net-info ceph-cluster &>/dev/null; then
    virsh net-define $DIR/../../bridge/ceph-cluster.xml
    virsh net-start ceph-cluster
    virsh net-autostart ceph-cluster
fi

source "$DIR/../../bridge/br-server.bash"

virt-install \
  --name "$DOMAIN_NAME" \
  --ram 4096 --vcpus 2 \
  --disk "/var/lib/libvirt/images/$DOMAIN_NAME-debian-13-generic-amd64.qcow2" \
  --disk "/var/lib/libvirt/images/$DOMAIN_NAME-osd.qcow2" \
  --disk "/var/lib/libvirt/images/$DOMAIN_NAME.iso,device=cdrom" \
  --os-variant debian13 \
  --import \
  --network bridge=br-server,virtualport_type=openvswitch,vlan.tag0.id=20 \
  --network network=ceph-cluster \
  --graphics vnc \
  --console pty,target_type=serial \
  --noautoconsole

if [[ -n "$ip_master" ]]; then
    echo "[ceph] waiting for $DOMAIN_NAME to be reachable and docker to be running..."
    until ssh -q -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o BatchMode=yes admin@"$DOMAIN_IP" "systemctl is-active --quiet docker" 2>/dev/null; do
        sleep 5
    done
    echo "[ceph] registering $DOMAIN_NAME as a cephadm-managed host from $MASTER_IP"
    ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null admin@"$MASTER_IP" "sudo cephadm shell -- ceph orch host add $DOMAIN_NAME $DOMAIN_IP"
fi