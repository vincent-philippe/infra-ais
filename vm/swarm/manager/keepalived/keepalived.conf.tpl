vrrp_instance VI_1 {
    state ${KEEPALIVED_STATE}
    interface enp1s0
    virtual_router_id ${KEEPALIVED_ROUTER_ID}
    priority ${KEEPALIVED_PRIORITY}
    advert_int 1
    unicast_src_ip ${KEEPALIVED_IP_ADDRESS}
    unicast_peer {
        ${KEEPALIVED_UNICAST_PEER}
    }
    authentication {
        auth_type PASS
        auth_pass ${KEEPALIVED_PWD}
    }
    virtual_ipaddress {
        ${SWARM_VIP_ADDRESS}/27
    }
}