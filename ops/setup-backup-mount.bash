#!/bin/bash
# setup-backup-mount.bash - Map the Ceph backup-pool RBD image on the KVM host
# and mount it, so rbd-backup.bash has a Ceph-backed destination in addition
# to the local host directory (see rbd-backup.crontab — both run).
# Requires the host able to reach the CEPH network (10.0.120.0/24) via the
# ADMIN leg — see netplan/01-network.yaml.
# Usage: ./setup-backup-mount.bash --ceph-ip <master-ip>
set -e
if [[ $EUID -ne 0 ]]; then
    echo "Ce script doit être lancé en root"
    exit 1
fi

###############MENU###############
POOL_NAME="backup-pool"
IMAGE_NAME="vm-backups"
IMAGE_SIZE_GB=300
MOUNT_POINT="/mnt/ceph-backup"
while [[ $# -gt 0 ]]; do
    case $1 in
        --ceph-ip) ceph_ip="$2"; shift 2 ;;
        --pool-name) POOL_NAME="$2"; shift 2 ;;
        --image-name) IMAGE_NAME="$2"; shift 2 ;;
        --image-size-gb) IMAGE_SIZE_GB="$2"; shift 2 ;;
        --mount-point) MOUNT_POINT="$2"; shift 2 ;;
        --help) echo "Usage: $0 --ceph-ip <master-ip> [--pool-name <name>] [--image-name <name>] [--image-size-gb <n>] [--mount-point <path>]"; exit 0 ;;
        *) echo "Unknown option $1"; exit 1 ;;
    esac
done

if [[ -z "$ceph_ip" ]]; then
    echo "[error] --ceph-ip must be set"
    exit 1
fi
###############MENU###############

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/../vm/_scripts/load-env.bash"

if ! command -v rbd &>/dev/null; then
    echo "[host] installing ceph-common"
    apt update && apt install -y ceph-common
fi

SSH_OPTS=(-i "$SSH_KEY_PATH" -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null)

echo "[ceph] fetching ceph.conf and client.backup keyring from $ceph_ip"
mkdir -p /etc/ceph
ssh -q "${SSH_OPTS[@]}" admin@"$ceph_ip" "sudo cat /etc/ceph/ceph.conf" > /etc/ceph/ceph.conf
ssh -q "${SSH_OPTS[@]}" admin@"$ceph_ip" "sudo cat /etc/ceph/ceph.client.backup.keyring" > /etc/ceph/ceph.client.backup.keyring
chmod 0600 /etc/ceph/ceph.client.backup.keyring

RBD="rbd --id backup"

if ! $RBD ls "$POOL_NAME" 2>/dev/null | grep -qx "$IMAGE_NAME"; then
    echo "[ceph] creating rbd image $POOL_NAME/$IMAGE_NAME (${IMAGE_SIZE_GB}G)"
    $RBD create "$POOL_NAME/$IMAGE_NAME" --size "${IMAGE_SIZE_GB}G"
fi

echo "[ceph] registering $POOL_NAME/$IMAGE_NAME in /etc/ceph/rbdmap"
RBDMAP_LINE="$POOL_NAME/$IMAGE_NAME id=backup,keyring=/etc/ceph/ceph.client.backup.keyring"
touch /etc/ceph/rbdmap
grep -qxF "$RBDMAP_LINE" /etc/ceph/rbdmap || echo "$RBDMAP_LINE" >> /etc/ceph/rbdmap

echo "[ceph] mapping $POOL_NAME/$IMAGE_NAME"
systemctl enable --now rbdmap
DEVICE="/dev/rbd/$POOL_NAME/$IMAGE_NAME"
until [[ -e "$DEVICE" ]]; do sleep 1; done

if ! blkid "$DEVICE" &>/dev/null; then
    echo "[host] formatting $DEVICE as xfs (first use)"
    mkfs.xfs "$DEVICE"
fi

mkdir -p "$MOUNT_POINT"
FSTAB_LINE="$DEVICE $MOUNT_POINT xfs _netdev,noauto,x-systemd.requires=rbdmap.service 0 0"
grep -qxF "$FSTAB_LINE" /etc/fstab || echo "$FSTAB_LINE" >> /etc/fstab

mountpoint -q "$MOUNT_POINT" || mount "$MOUNT_POINT"

echo "[host] done — $POOL_NAME/$IMAGE_NAME mounted at $MOUNT_POINT"
