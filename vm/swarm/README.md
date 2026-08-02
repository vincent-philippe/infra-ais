# docker swarm

### swarm manager

Noeud manager du cluster actif swarm

**Variables d'environnement** 

|     | Valeur |
| -------- | ------- |
| AUTHORIZED_KEY | la clé de l'utilisateur (admin) pour connection ssh à l'instance (exemple : voir [`.env.example`](/.env.example)) |

**Caractéristiques technique** 

RAM : 4go
cpu : 2cpu
os : [debian 13](https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2)
disk : 20go (essentiellement pour les logs, les volumes sont externalisés via NFS)

___
- Initialize using 

```
$ sudo make init-swarm ARGS="--swarm-mode manager --domain-name swarm-1"
```

- Connect using

```
ssh admin@$(virsh domifaddr swarm-1 | grep 192. | cut -d " " -f 20 | cut -d "/" -f 1)
```

### swarm worker

Noeud worker du cluster actif swarm, joint automatiquement le swarm, via configuration.

**Variables d'environnement** 

|     | Valeur |
| -------- | ------- |
| AUTHORIZED_KEY | la clé de l'utilisateur (admin) pour connection ssh à l'instance (exemple : voir [`.env.example`](/.env.example)) |
| SWARM_TOKEN | le token swarm pour joindre le cluster swarm (exemple : voir [`.env.example`](/.env.example)) |

**Caractéristiques technique**

RAM : 2go
cpu : 2cpu
os : basé sur [debian 13](https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2)
disk : 20go (essentiellement pour les logs, les volumes sont externalisés via NFS)

___
- Initialize using 

```
$ sudo make init-swarm ARGS="--swarm-mode worker --domain-name worker-1"
```

- Connect using

```
ssh admin@$(virsh domifaddr worker-1 | grep 192. | cut -d " " -f 20 | cut -d "/" -f 1)
```