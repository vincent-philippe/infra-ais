#!/bin/bash
# The following boot stage of cloud init :
# - Config : main configuration (meta-data)
# - Final : User script (user-data)

echo "[cloud-init] reading user-data and meta-data for $DOMAIN_NAME..."

envsubst < "$DIR/meta-data.yml" > "/tmp/$DOMAIN_NAME.meta-data.yml"
envsubst < "$DIR/user-data.yml" > "/tmp/$DOMAIN_NAME.user-data.yml"

cloud-localds "/tmp/$DOMAIN_NAME.iso" "/tmp/$DOMAIN_NAME.user-data.yml" "/tmp/$DOMAIN_NAME.meta-data.yml"
cp "/tmp/$DOMAIN_NAME.iso" /var/lib/libvirt/images/

echo "[cloud-init] seed iso have been initialized at /tmp/$DOMAIN_NAME.iso..."

echo "[virt] installing the domain from cloud disk using seed instructions..."
