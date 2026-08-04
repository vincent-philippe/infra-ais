#!/bin/bash
# The following boot stage of cloud init :
# - Config : main configuration (meta-data)
# - Final : User script (user-data)

cp "$DIR/meta-data.yml" "/tmp/$domain_name.meta-data.yml"

sed -i "s|{instance-id}|$instance_id|" "/tmp/$domain_name.meta-data.yml"
sed -i "s|{domain-name}|$domain_name|" "/tmp/$domain_name.meta-data.yml"

echo "[cloud-init] reading user-data and meta-data for $domain_name..."

envsubst < "$DIR/user-data.yml" > "/tmp/$domain_name.user-data.yml"

cloud-localds "/tmp/$domain_name.iso" "/tmp/$domain_name.user-data.yml" "/tmp/$domain_name.meta-data.yml"
cp "/tmp/$domain_name.iso" /var/lib/libvirt/images/

echo "[cloud-init] seed iso have been initialized at /tmp/$domain_name.iso..."

echo "[virt] installing the domain from cloud disk using seed instructions..."
