#!/bin/bash
# The following boot stage of cloud init :
# - Config : main configuration (meta-data)
# - Final : User script (user-data)

CLOUD_OPTS=()
CLOUD_ARGS=()

echo "[cloud-init] reading user-data and meta-data for $DOMAIN_NAME..."

touch "/tmp/$DOMAIN_NAME.meta-data.yml" "/tmp/$DOMAIN_NAME.user-data.yml" "/tmp/$DOMAIN_NAME.network-data.yml"

envsubst < "$DIR/meta-data.yml" > "/tmp/$DOMAIN_NAME.meta-data.yml"
envsubst < "$DIR/user-data.yml" > "/tmp/$DOMAIN_NAME.user-data.yml"
set +e
cloud-init schema --config-file "/tmp/$DOMAIN_NAME.user-data.yml" --annotate || exit 1;
set -e
#>OPTIONAL NETWORK CONF>#
if [[ -s "$DIR/network-data.yml" ]]; then
    envsubst < "$DIR/network-data.yml" > "/tmp/$DOMAIN_NAME.network-data.yml"
    CLOUD_OPTS+=( --network-config "/tmp/$DOMAIN_NAME.network-data.yml" )
    set +e
    cloud-init schema --config-file "/tmp/$DOMAIN_NAME.network-data.yml" --schema-type network-config --annotate || exit 1;
    set -e
fi
#<OPTIONAL NETWORK CONF<#

CLOUD_ARGS+=("/tmp/$DOMAIN_NAME.user-data.yml")
CLOUD_ARGS+=("/tmp/$DOMAIN_NAME.meta-data.yml")

cloud-localds "${CLOUD_OPTS[@]}" "/tmp/$DOMAIN_NAME.iso" "${CLOUD_ARGS[@]}"
cp "/tmp/$DOMAIN_NAME.iso" /var/lib/libvirt/images/

echo "[cloud-init] seed iso have been initialized at /tmp/$DOMAIN_NAME.iso..."

echo "[virt] installing the domain from cloud disk using seed instructions..."