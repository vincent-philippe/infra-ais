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
