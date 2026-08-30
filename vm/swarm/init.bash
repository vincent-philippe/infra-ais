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
        --ip-address) ip_address="$2"; shift 2 ;;
        --ip-server-address) ip_server_address="$2"; shift 2 ;;
        --ceph-ip-address) ceph_ip_address="$2"; shift 2 ;;
        --keep-alived-conf) keep_alived_conf="$2"; shift 2 ;;
        --help) echo "Usage: $0 --swarm-mode <mode> --instance-id <id> --domain-name <name> --ip-address <ip> --ip-server-address <ip/cidr> [--ceph-ip-address <ceph-ip>] [--keep-alived-conf <path>]"; exit 0 ;;
        *) echo "Unknown option $1"; exit 1 ;;
    esac
done

if [[ -z "$ip_address" ]]; then
    echo "[error] --ip-address must be set (address on br-dmz — public-facing, this is what WAN:80/443 gets forwarded to)"
    exit 1
fi

if [[ -z "$ip_server_address" ]]; then
    echo "[error] --ip-server-address must be set (address on br-server VLAN 30 — private channel to harbor/ceph only)"
    exit 1
fi

export SWARM_MODE=${swarm_mode:-"manager"}
export DOMAIN_NAME=${domain_name:-"swarm-1"}
export INSTANCE_ID=${instance_id:-$DOMAIN_NAME}
export DOMAIN_IP_ADDRESS=${ip_address}
export DOMAIN_IP=${ip_address%%/*}
export SERVER_IP_ADDRESS=${ip_server_address}
export CEPH_IP_ADDRESS=${ceph_ip_address}
export CEPH_IP=${ceph_ip_address%%/*}

###############MENU###############

# base directory to load user/meta data
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# depending on mode, the user/meta data would differr
case $SWARM_MODE in
    "worker") DIR="${DIR}/worker" ;;
    "manager") DIR="${DIR}/manager" ;;
    *) echo "mode should be either worker or manager" ; exit 1 ;;
esac

source "$DIR/../../_scripts/load-env.bash"

if [[ -n "$ceph_ip_address" ]]; then
    echo "[ceph] fetching client keyrings and cluster conf from $CEPH_IP"
    export CEPH_CONF=$(ssh -q -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null admin@"$CEPH_IP" "sudo cat /etc/ceph/ceph.conf" | base64 -w 0)
    export CEPH_ADMIN_KEYRING=$(ssh -q -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null admin@"$CEPH_IP" "sudo cat /etc/ceph/ceph.client.admin.keyring" | base64 -w 0)
    export CEPH_DOCKER_KEYRING=$(ssh -q -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null admin@"$CEPH_IP" "sudo cat /etc/ceph/ceph.client.docker.keyring" | base64 -w 0)
fi

if [[ $SWARM_MODE == "manager" ]]; then
    if [[ -z "$keep_alived_conf" ]]; then
        echo "[error] --keep-alived-conf must be set for manager mode"
        exit 1
    fi
    export TRAEFIK_TLS_CONF=$(base64 "$DIR/traefik/conf/tls.yml" -w 0)
    envsubst < "$DIR/traefik/conf/traefik.toml" > "/tmp/$DOMAIN_NAME.traefik.toml"
    export TRAEFIK_CONF=$(base64 "/tmp/$DOMAIN_NAME.traefik.toml" -w 0)
    envsubst < "$DIR/traefik/docker-compose-swarm.yml" > "/tmp/$DOMAIN_NAME.traefik.docker-compose-swarm.yml"
    export COMPOSE_TRAEFIK=$(base64 "/tmp/$DOMAIN_NAME.traefik.docker-compose-swarm.yml" -w 0)
    export KEEPALIVED_CONF=$(base64 "$keep_alived_conf" -w 0)
fi

source "$DIR/../../_scripts/boot-cloud-init.bash"

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
  "/var/lib/libvirt/images/$DOMAIN_NAME-debian-13-generic-amd64.qcow2" 20G

source "$DIR/../../bridge/br-server.bash"

virt-install \
  --name "$DOMAIN_NAME" \
  --memory 4000 \
  --vcpus 2 \
  --disk "/var/lib/libvirt/images/$DOMAIN_NAME-debian-13-generic-amd64.qcow2" \
  --disk "/var/lib/libvirt/images/$DOMAIN_NAME.iso,device=cdrom" \
  --network bridge=br-dmz \
  --network bridge=br-server,virtualport_type=openvswitch \
  --os-variant debian13 \
  --import \
  --graphics vnc,password="$VNC_PASSWORD" \
  --console pty,target_type=serial \
  --noautoconsole

br_server_set_vlan "$DOMAIN_NAME" 30

echo "[virt] done !"
echo "[virt] domain has been defined and is now running..."
virsh list | grep "$DOMAIN_NAME"