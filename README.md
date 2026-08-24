
[architecture.md *draft*](./docs/architecture.md)

## Environments variables

Définir les variables d'environnements, copier le ficheir .env.example et suivre les instructions 
dans les fichiers des différents machines.

## Getting started : 

Add the following hosts (/!\ Wait that vm are booted between each steps /!\)

**Building External configuration files**

*Keepalived configuration for swarm cluster*
```
$ cp ./vm/swarm/manager/keepalived/keepalived.conf.tpl /tmp/keepalived.conf.swarm1.1 && sed -i 's/${KEEPALIVED_UNICAST_PEER}/192.168.122.11\n\t192.168.122.12/g' /tmp/keepalived.conf.swarm1.1 && export KEEPALIVED_IP_ADDRESS=192.168.122.10 KEEPALIVED_STATE="MASTER" KEEPALIVED_ROUTER_ID=51 KEEPALIVED_PRIORITY=150 SWARM_VIP_ADDRESS=192.168.122.13 && set -a && . ./.env && set +a && envsubst < /tmp/keepalived.conf.swarm1.1 > /tmp/keepalived.conf.swarm1 && cat /tmp/keepalived.conf.swarm1

$ cp ./vm/swarm/manager/keepalived/keepalived.conf.tpl /tmp/keepalived.conf.swarm2.1 && sed -i 's/${KEEPALIVED_UNICAST_PEER}/192.168.122.10\n\t192.168.122.12/g' /tmp/keepalived.conf.swarm2.1 && export CEPH_IP_ADDRESS="192.168.122.6" KEEPALIVED_IP_ADDRESS=192.168.122.11 KEEPALIVED_STATE="BACKUP" KEEPALIVED_ROUTER_ID=51 KEEPALIVED_PRIORITY=100 SWARM_VIP_ADDRESS=192.168.122.13 && set -a && . ./.env && set +a && envsubst < /tmp/keepalived.conf.swarm2.1 > /tmp/keepalived.conf.swarm2 && cat /tmp/keepalived.conf.swarm2

$ cp ./vm/swarm/manager/keepalived/keepalived.conf.tpl /tmp/keepalived.conf.swarm3.1 && sed -i 's/${KEEPALIVED_UNICAST_PEER}/192.168.122.10\n\t192.168.122.11/g' /tmp/keepalived.conf.swarm3.1 && export CEPH_IP_ADDRESS="192.168.122.6" KEEPALIVED_IP_ADDRESS=192.168.122.12 KEEPALIVED_STATE="BACKUP" KEEPALIVED_ROUTER_ID=51 KEEPALIVED_PRIORITY=50 SWARM_VIP_ADDRESS=192.168.122.13 && set -a && . ./.env && set +a && envsubst < /tmp/keepalived.conf.swarm3.1 > /tmp/keepalived.conf.swarm3 && cat /tmp/keepalived.conf.swarm3
```

**Init all vm**

```
$ sudo make init-ceph-node NAME="ceph-1" IP="192.168.122.6/27" CLUSTER_INTERNAL_IP="10.0.1.6/24" CLUSTER_NETWORK="10.0.1.0/24"

$ sudo make init-ceph-node NAME="ceph-2" IP="192.168.122.7/27" CLUSTER_INTERNAL_IP="10.0.1.7/24" IP_MASTER="192.168.122.6/27"

$ sudo make init-ceph-node NAME="ceph-3" IP="192.168.122.8/27" CLUSTER_INTERNAL_IP="10.0.1.8/24" IP_MASTER="192.168.122.6/27"

$ sudo make init-harbor NAME=harbor-1 IP="192.168.122.14/27"

$ sudo make init-swarm-manager NAME="swarm-1" IP=192.168.122.10/27" KEEP_ALIVED_CONF=/tmp/keepalived.conf.swarm1 CEPH_IP_ADDRESS="192.168.122.6"

$ sudo make init-swarm-manager NAME="swarm-2" IP=192.168.122.11/27" CEPH_IP="192.168.122.6/27"

$ sudo make init-swarm-manager NAME="swarm-3" IP=192.168.122.12/27" CEPH_IP="192.168.122.6/27"

$ sudo make deploy-harbor-cert-to-swarm HARBOR_IP=192.168.122.14 SWARM_IP="192.168.122.10 192.168.122.11 192.168.122.12"

$ sudo make deploy-game-app
```

## Détail des vms

### Swarm

[swarm](./vm/swarm/_docs/README.md)

### Registry Harbor

[registry](./vm/registry/_docs/README.md)