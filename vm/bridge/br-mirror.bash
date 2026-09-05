#!/bin/bash

br_set_mirror() {
    local domain_name="$1"
    local bridge_name="$2"
    local mac="$3"
    local port
    port="$(virsh domiflist "$domain_name" | awk -v br="$bridge_name" -v mac="$mac" '$3 == br && (mac == "" || $5 == mac) {print $1}')"
    if [[ -z "$port" ]]; then
        echo "[error] no $bridge_name port found for domain $domain_name"
        exit 1
    fi
    ovs-vsctl -- --id=@p get port "$port" \
              -- --id=@m create mirror name="mirror-$bridge_name-$domain_name" select-all=true output-port=@p \
              -- add bridge "$bridge_name" mirrors @m
}
