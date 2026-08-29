
[architecture.md *draft*](./docs/architecture.md)

## Environments variables

Définir les variables d'environnements, copier le ficheir .env.example et suivre les instructions 
dans les fichiers des différents machines.

## Getting started : 

Add the following hosts (/!\ Wait that vm are booted between each steps /!\)

**Applying the host network configuration (netplan)**

The bridges defined in `netplan/` (`br-wan`, `br-user`, `br-admin`, `br-dmz`) must exist on the host. Run the following netplan configuration to create them.

```
$ sudo cp netplan/*.yaml /etc/netplan/
$ sudo netplan try
```

**Building External configuration files**

*Keepalived configuration for swarm cluster*
```
$ cp ./vm/swarm/manager/keepalived/keepalived.conf.tpl /tmp/keepalived.conf.swarm1.1 && sed -i 's/${KEEPALIVED_UNICAST_PEER}/192.168.122.11\n\t192.168.122.12/g' /tmp/keepalived.conf.swarm1.1 && export KEEPALIVED_IP_ADDRESS=192.168.122.10 KEEPALIVED_STATE="MASTER" KEEPALIVED_ROUTER_ID=51 KEEPALIVED_PRIORITY=150 SWARM_VIP_ADDRESS=192.168.122.13 && set -a && . ./.env && set +a && envsubst < /tmp/keepalived.conf.swarm1.1 > /tmp/keepalived.conf.swarm1 && cat /tmp/keepalived.conf.swarm1

$ cp ./vm/swarm/manager/keepalived/keepalived.conf.tpl /tmp/keepalived.conf.swarm2.1 && sed -i 's/${KEEPALIVED_UNICAST_PEER}/192.168.122.10\n\t192.168.122.12/g' /tmp/keepalived.conf.swarm2.1 && export CEPH_IP_ADDRESS="10.0.120.6" KEEPALIVED_IP_ADDRESS=192.168.122.11 KEEPALIVED_STATE="BACKUP" KEEPALIVED_ROUTER_ID=51 KEEPALIVED_PRIORITY=100 SWARM_VIP_ADDRESS=192.168.122.13 && set -a && . ./.env && set +a && envsubst < /tmp/keepalived.conf.swarm2.1 > /tmp/keepalived.conf.swarm2 && cat /tmp/keepalived.conf.swarm2

$ cp ./vm/swarm/manager/keepalived/keepalived.conf.tpl /tmp/keepalived.conf.swarm3.1 && sed -i 's/${KEEPALIVED_UNICAST_PEER}/192.168.122.10\n\t192.168.122.11/g' /tmp/keepalived.conf.swarm3.1 && export CEPH_IP_ADDRESS="10.0.120.6" KEEPALIVED_IP_ADDRESS=192.168.122.12 KEEPALIVED_STATE="BACKUP" KEEPALIVED_ROUTER_ID=51 KEEPALIVED_PRIORITY=50 SWARM_VIP_ADDRESS=192.168.122.13 && set -a && . ./.env && set +a && envsubst < /tmp/keepalived.conf.swarm3.1 > /tmp/keepalived.conf.swarm3 && cat /tmp/keepalived.conf.swarm3
```

**Init all vm**

```
$ sudo make init-opnsense

$ sudo make init-ceph-node-master NAME="ceph-1" IP="10.0.120.6/24" IP_INTERNAL_CLUSTER="10.0.1.6/24" CLUSTER_NETWORK="10.0.1.0/24"

$ sudo make init-ceph-node NAME="ceph-2" IP="10.0.120.7/24" IP_INTERNAL_CLUSTER="10.0.1.7/24" IP_MASTER="10.0.120.6/24"

$ sudo make init-ceph-node NAME="ceph-3" IP="10.0.120.8/24" IP_INTERNAL_CLUSTER="10.0.1.8/24" IP_MASTER="10.0.120.6/24"

$ sudo make init-harbor NAME=harbor-1 IP="10.0.110.14/24"

$ sudo make init-swarm-manager NAME="swarm-1" IP="192.168.122.10/27" SERVER_IP="10.0.130.10/24" KEEP_ALIVED_CONF=/tmp/keepalived.conf.swarm1 CEPH_IP_ADDRESS="10.0.120.6/24"

$ sudo make init-swarm-manager NAME="swarm-2" IP="192.168.122.11/27" SERVER_IP="10.0.130.11/24" KEEP_ALIVED_CONF=/tmp/keepalived.conf.swarm2 CEPH_IP_ADDRESS="10.0.120.6/24"

$ sudo make init-swarm-manager NAME="swarm-3" IP="192.168.122.12/27" SERVER_IP="10.0.130.12/24" KEEP_ALIVED_CONF=/tmp/keepalived.conf.swarm3 CEPH_IP_ADDRESS="10.0.120.6/24"

$ sudo make deploy-harbor-cert-to-swarm HARBOR_IP=10.0.110.14 SWARM_IP="192.168.122.10 192.168.122.11 192.168.122.12"

$ sudo make deploy-game-app
```

## Détail des vms

### Swarm

[swarm](./vm/swarm/_docs/README.md)

### Registry Harbor

[registry](./vm/registry/_docs/README.md)