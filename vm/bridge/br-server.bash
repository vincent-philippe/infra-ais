#!/bin/bash

set +e
ovs-vsctl --version &>/dev/null
rc=$?
set -e
if [[ $rc -eq 127 ]]; then
    echo "[net] installing openvswitch-switch"
    apt update && apt install -y openvswitch-switch
fi

br_server_set_vlan() {
    local domain_name="$1"
    local vlan_spec="$2"
    local mac="$3"
    local port
    port="$(virsh domiflist "$domain_name" | awk -v mac="$mac" '$3 == "br-server" && (mac == "" || $5 == mac) {print $1}')"
    if [[ -z "$port" ]]; then
        echo "[error] no br-server port found for domain $domain_name"
        exit 1
    fi
    if [[ "$vlan_spec" == *,* ]]; then
        ovs-vsctl set port "$port" trunks="$vlan_spec"
    else
        ovs-vsctl set port "$port" tag="$vlan_spec"
    fi
}
