#!/bin/bash
# setup-ceph-client.bash - Give the KVM host a Ceph client identity so
# rbd-backup.bash can read docker-pool. The backup destination itself is a
# plain local directory on the host (see rbd-backup.crontab) — this script
# does not touch backup-pool or mount anything, it only fetches what's
# needed to talk to docker-pool over the wire.
# Requires the host able to reach the CEPH network (10.0.120.0/24) via the
# ADMIN leg — see netplan/01-network.yaml.
# Usage: ./setup-ceph-client.bash --ceph-ip <master-ip>
set -e
if [[ $EUID -ne 0 ]]; then
    echo "Ce script doit être lancé en root"
    exit 1
fi

while [[ $# -gt 0 ]]; do
    case $1 in
        --ceph-ip) ceph_ip="$2"; shift 2 ;;
        --help) echo "Usage: $0 --ceph-ip <master-ip>"; exit 0 ;;
        *) echo "Unknown option $1"; exit 1 ;;
    esac
done

if [[ -z "$ceph_ip" ]]; then
    echo "[error] --ceph-ip must be set"
    exit 1
fi

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/../vm/_scripts/load-env.bash"

if ! command -v rbd &>/dev/null; then
    echo "[host] installing ceph-common"
    apt update && apt install -y ceph-common
fi

SSH_OPTS=(-i "$SSH_KEY_PATH" -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null)

echo "[ceph] fetching ceph.conf and client.docker keyring from $ceph_ip"
mkdir -p /etc/ceph
ssh -q "${SSH_OPTS[@]}" admin@"$ceph_ip" "sudo cat /etc/ceph/ceph.conf" > /etc/ceph/ceph.conf
ssh -q "${SSH_OPTS[@]}" admin@"$ceph_ip" "sudo cat /etc/ceph/ceph.client.docker.keyring" > /etc/ceph/ceph.client.docker.keyring
chmod 0600 /etc/ceph/ceph.client.docker.keyring

echo "[host] done — rbd --id docker ... can now reach docker-pool"
