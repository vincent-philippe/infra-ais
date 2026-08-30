# docker swarm

### swarm manager

Noeud manager du cluster actif swarm. Deux NIC : une sur `br-dmz` (publique,
c'est elle que WAN:80/443 cible via DNAT) et une sur `br-server` VLAN 30
(privée, vers HARBOR/CEPH uniquement).

**Variables d'environnement**

|     | Valeur |
| -------- | ------- |
| SWARM_TOKEN_MANAGER | Le token swarm pour joindre le cluster en tant que manager (exemple : voir [`.env.example`](/.env.example)) |
| TRAEFIK_HOST | Le nom de domaine auquel traefik est joignable (exemple : voir [`.env.example`](/.env.example)) |
| HARBOR_DOMAIN_NAME, HARBOR_ROBOT_ACCOUNT, HARBOR_ROBOT_PASSWORD | Utilisés pour le `docker login` vers le registre privé Harbor (exemple : voir [`.env.example`](/.env.example)) |

**Caractéristiques technique**

RAM : 4go
cpu : 2cpu
os : [debian 13](https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2)
disk : 20go (essentiellement pour les logs, les volumes sont externalisés via NFS @TODO)

___
- Initialize using

```
$ sudo make init-swarm-manager NAME=swarm-1 IP=192.168.122.10/27 SERVER_IP=10.0.130.10/24 KEEP_ALIVED_CONF=./keepalived.conf CEPH_IP_ADDRESS=10.0.120.6/24
```

- Connect using

```
ssh admin@192.168.122.10
```

## Network

Les networks sont créés automatiquement au lancement de la VM, ils sont documentés ici à titre indicatif.


|     | Valeur |
| -------- | ------- |
| traefik | [driver=overlay] Réseau **publique** utilisé par tous service nécessitant d'être exposé publiquement (api / front / ...) |
| socket-proxy-network | [driver=overlay] Réseau **privé** utilisé uniquement par traefik pour le [service discovery](https://traefik.io/glossary/service-discovery). Ce réseau n'est pas connecté au router principal, et n'à aucune accès externe. |


### swarm worker

Noeud worker du cluster actif swarm, joint automatiquement le swarm, via configuration.

**Variables d'environnement**

|     | Valeur |
| -------- | ------- |
| SWARM_TOKEN_WORKER | Le token swarm pour joindre le cluster en tant que worker (exemple : voir [`.env.example`](/.env.example)) |

**Caractéristiques technique**

RAM : 2go
cpu : 2cpu
os : basé sur [debian 13](https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2)
disk : 20go (essentiellement pour les logs, les volumes sont externalisés via NFS @TODO)

___
- Initialize using

```
$ sudo make init-swarm-worker NAME=worker-1 IP=192.168.122.11/27 SERVER_IP=10.0.130.11/24 CEPH_IP_ADDRESS=10.0.120.6/24
```

- Connect using

```
ssh admin@192.168.122.11
```
