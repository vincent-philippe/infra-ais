#!/bin/bash

set -e

set +e
ovs-vsctl --version &>/dev/null
set -e
if [[ $? -eq 127 ]]; then
    echo "[net] installing openvswitch-switch"
    apt update && apt install -y openvswitch-switch
fi

if ! ovs-vsctl br-exists br-server; then
    echo "[net] creating OVS bridge br-server"
    ovs-vsctl add-br br-server
fi

br_server_set_vlan() {
    local domain_name="$1"
    local vlan_spec="$2"
    local port
    port="$(virsh domiflist "$domain_name" | awk '$3 == "br-server" {print $1}')"
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
