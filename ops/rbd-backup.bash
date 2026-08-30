#!/bin/bash
# rbd-backup.bash - Backup every image in an RBD pool into one or more Borg
# repos, via a single rbd export (one snapshot, one Ceph read) fanned out to
# each -r destination.
# Source: https://medium.com/@cedric.nanni/backup-ceph-rbd-vm-with-borgbackup-fad04d359c74
# Prerequisites: `apt install borgbackup`, the host has a Ceph client identity
# for the pool (see setup-ceph-client.bash), and every target repo already
# initialized — `borg init --encryption=none <repo>` (once).

usage() {
    echo "Usage: $0 -p <pool> -s <snapshot_name> -r <borg_repo> [-r <borg_repo> ...] -u <ceph_user>"
    echo "  -p <pool>          : Name of the pool to backup."
    echo "  -s <snapshot_name> : Name of the snapshot to create."
    echo "  -r <borg_repo>     : Path of a borg repository. Repeatable for multiple destinations."
    echo "  -u <ceph_user>     : Ceph user name."
    exit 1
}

BORG_REPOS=()
while getopts "p:s:r:u:" opt; do
    case $opt in
        p) POOL="$OPTARG" ;;
        s) SNAPSHOT_NAME="$OPTARG" ;;
        r) BORG_REPOS+=("$OPTARG") ;;
        u) CEPH_USER="$OPTARG" ;;
        *) usage ;;
    esac
done

if [ -z "${POOL}" ] || [ -z "${SNAPSHOT_NAME}" ] || [ ${#BORG_REPOS[@]} -eq 0 ] || [ -z "${CEPH_USER}" ]; then
    usage
fi

echo "Starting backup of pool: ${POOL}"

IMAGES=$(rbd --id "${CEPH_USER}" ls "${POOL}")
if [ $? -ne 0 ]; then
    echo "Error: Failed to list images in pool ${POOL}"
    exit 1
fi

if [ -z "${IMAGES}" ]; then
    echo "No images found in pool ${POOL}. Nothing to backup."
    exit 0
fi

for IMAGE in ${IMAGES}; do
    SNAPSHOT="${POOL}/${IMAGE}@${SNAPSHOT_NAME}"
    rbd --id "${CEPH_USER}" snap ls "${POOL}/${IMAGE}" | grep -q "${SNAPSHOT_NAME}"
    if [ $? -eq 0 ]; then
        echo "Snapshot ${SNAPSHOT_NAME} already exists for ${IMAGE}. Attempting to delete it."
        rbd --id "${CEPH_USER}" --no-progress snap rm "${SNAPSHOT}"
        if [ $? -ne 0 ]; then
            echo "Error: Failed to delete existing snapshot ${SNAPSHOT_NAME} for ${IMAGE}. Skipping backup."
            continue
        fi
    fi

    echo "Creating snapshot ${SNAPSHOT_NAME} for ${POOL}/${IMAGE}"
    rbd --id "${CEPH_USER}" --no-progress snap create "${POOL}/${IMAGE}@${SNAPSHOT_NAME}"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create snapshot ${SNAPSHOT_NAME} for ${IMAGE}"
        continue
    fi

    echo "Exporting ${POOL}/${IMAGE} once for all destinations"
    ARCHIVE="${POOL}-${IMAGE}-$(date +%Y%m%d_%H:%M:%S)"
    TMP_DIR="$(mktemp -d)"
    TMP_EXPORT="${TMP_DIR}/${IMAGE}.img"
    rbd --id "${CEPH_USER}" --no-progress export "${POOL}/${IMAGE}@${SNAPSHOT_NAME}" "${TMP_EXPORT}"
    if [ $? -ne 0 ]; then
        echo "Error: Export failed for ${IMAGE}"
        rm -rf "${TMP_DIR}"
        continue
    fi

    for BORG_REPO in "${BORG_REPOS[@]}"; do
        echo "Backing up ${IMAGE} to ${BORG_REPO}"
        borg create --verbose --stats --stdin-name "${IMAGE}.img" \
                "${BORG_REPO}::${ARCHIVE}" - < "${TMP_EXPORT}"
        if [ $? -ne 0 ]; then
            echo "Error: Backup failed for ${IMAGE} on ${BORG_REPO}"
            continue
        fi

        echo "Checking archive integrity for ${ARCHIVE} on ${BORG_REPO}"
        borg check "${BORG_REPO}::${ARCHIVE}"
        if [ $? -ne 0 ]; then
            echo "Error: integrity check failed for ${IMAGE} on ${BORG_REPO} (archive ${ARCHIVE}) — treating this backup as unusable"
            continue
        fi

        echo "Pruning borg repo ${BORG_REPO} for ${POOL}/${IMAGE}"
        borg prune --list --glob-archives "${POOL}-${IMAGE}-*" "${BORG_REPO}" \
                --keep-hourly=2 --keep-daily=1 --keep-weekly=2
        if [ $? -ne 0 ]; then
            echo "Error: Failed to prune borg repo ${BORG_REPO} for ${IMAGE}"
        fi
    done

    rm -rf "${TMP_DIR}"

    echo "Deleting snapshot ${SNAPSHOT_NAME} for ${POOL}/${IMAGE}"
    rbd --id "${CEPH_USER}" --no-progress snap rm "${POOL}/${IMAGE}@${SNAPSHOT_NAME}"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to delete snapshot for ${IMAGE}"
        continue
    fi

    echo "Backup completed for ${IMAGE}"

done

echo "Backup of pool ${POOL} completed successfully."

exit 0
