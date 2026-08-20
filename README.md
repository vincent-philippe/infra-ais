
[architecture.md *draft*](./docs/architecture.md)

## Environments variables

Définir les variables d'environnements, copier le ficheir .env.example et suivre les instructions 
dans les fichiers des différents machines.

## Getting started : 

Add the following hosts (/!\ Wait that vm are booted between each steps /!\)

```
$ sudo make init-harbor NAME=harbor-1 IP=192.168.122.14/24

$ cp ./vm/swarm/manager/keepalived/keepalived.conf.tpl /tmp/keepalived.conf.swarm1.1 && sed -i 's/${KEEPALIVED_UNICAST_PEER}/192.168.122.11\n\t192.168.122.12/g' /tmp/keepalived.conf.swarm1.1 && export KEEPALIVED_IP_ADDRESS=192.168.122.10 KEEPALIVED_STATE="MASTER" KEEPALIVED_ROUTER_ID=51 KEEPALIVED_PRIORITY=150 SWARM_VIP_ADDRESS=192.168.122.100 && set -a && . ./.env && set +a && envsubst < /tmp/keepalived.conf.swarm1.1 > /tmp/keepalived.conf.swarm1 && cat /tmp/keepalived.conf.swarm1

$ sudo make init-swarm-manager NAME="swarm-1" IP=192.168.122.10/24" KEEP_ALIVED_CONF=/tmp/keepalived.conf.swarm1

$ cp ./vm/swarm/manager/keepalived/keepalived.conf.tpl /tmp/keepalived.conf.swarm2.1 && sed -i 's/${KEEPALIVED_UNICAST_PEER}/192.168.122.10\n\t192.168.122.12/g' /tmp/keepalived.conf.swarm2.1 && export KEEPALIVED_IP_ADDRESS=192.168.122.11 KEEPALIVED_STATE="BACKUP" KEEPALIVED_ROUTER_ID=51 KEEPALIVED_PRIORITY=100 SWARM_VIP_ADDRESS=192.168.122.100 && set -a && . ./.env && set +a && envsubst < /tmp/keepalived.conf.swarm2.1 > /tmp/keepalived.conf.swarm2 && cat /tmp/keepalived.conf.swarm2

$ sudo make init-swarm-manager NAME="swarm-2" IP=192.168.122.11/24"

$ cp ./vm/swarm/manager/keepalived/keepalived.conf.tpl /tmp/keepalived.conf.swarm3.1 && sed -i 's/${KEEPALIVED_UNICAST_PEER}/192.168.122.10\n\t192.168.122.11/g' /tmp/keepalived.conf.swarm3.1 && export KEEPALIVED_IP_ADDRESS=192.168.122.12 KEEPALIVED_STATE="BACKUP" KEEPALIVED_ROUTER_ID=51 KEEPALIVED_PRIORITY=50 SWARM_VIP_ADDRESS=192.168.122.100 && set -a && . ./.env && set +a && envsubst < /tmp/keepalived.conf.swarm3.1 > /tmp/keepalived.conf.swarm3 && cat /tmp/keepalived.conf.swarm3

$ sudo make init-swarm-manager NAME="swarm-3" IP=192.168.122.12/24"

$ sudo make deploy-harbor-cert-to-swarm HARBOR_IP=192.168.122.14 SWARM_IP="192.168.122.10 192.168.122.11 192.168.122.12"

$ sudo make deploy-game-app
```

## Détail des vms

### Swarm

[swarm](./vm/swarm/_docs/README.md)

### Registry Harbor

[registry](./vm/registry/_docs/README.md)