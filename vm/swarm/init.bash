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

export SWARM_MODE=${swarm_mode:-"manager"}
export DOMAIN_NAME=${domain_name:-"swarm-1"}
export INSTANCE_ID=${instance_id:-$DOMAIN_NAME}
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

export TRAEFIK_TLS_CONF=$(base64 "$DIR/traefik/conf/tls.yml" -w 0)
envsubst < "$DIR/traefik/conf/traefik.toml" > "/tmp/$DOMAIN_NAME/traefik/traefik.tom"
export TRAEFIK_CONF=$(base64 "/tmp/$DOMAIN_NAME/traefik/traefik.tom" -w 0)
envsubst < "$DIR/traefik/docker-compose-swarm.yml" > "/tmp/$DOMAIN_NAME/traefik/docker-compose-swarm.yml"
export COMPOSE_TRAEFIK=$(base64 "/tmp/$DOMAIN_NAME/traefik/docker-compose-swarm.yml" -w 0)

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

virt-install \
  --name "$DOMAIN_NAME" \
  --memory 4000 \
  --vcpus 2 \
  --disk "/var/lib/libvirt/images/$DOMAIN_NAME-debian-13-generic-amd64.qcow2" \
  --disk "/var/lib/libvirt/images/$DOMAIN_NAME.iso,device=cdrom" \
  --network network=default \
  --os-variant debian13 \
  --import \
  --graphics vnc \
  --noautoconsole

echo "[virt] done !"
echo "[virt] domain has been defined and is now running..."
virsh list | grep "$DOMAIN_NAME"