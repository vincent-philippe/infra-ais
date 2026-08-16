# docker swarm

### swarm manager

Noeud manager du cluster actif swarm

**Variables d'environnement** 

|     | Valeur |
| -------- | ------- |
| AUTHORIZED_KEY | la clé de l'utilisateur (admin) pour connection ssh à l'instance (exemple : voir [`.env.example`](/.env.example)) |
| SWARM_IP_ADDRESS | L'ip (privée) du swarm (exemple : voir [`.env.example`](/.env.example)) |
| TRAEFIK_HOST | Le nom de domaine auquel traefik est joignable (exemple : voir [`.env.example`](/.env.example)) |

**Caractéristiques technique** 

RAM : 4go
cpu : 2cpu
os : [debian 13](https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2)
disk : 20go (essentiellement pour les logs, les volumes sont externalisés via NFS @TODO)

**Secrets**

Les secrets suivant doivent être définis


|     | Valeur |
| -------- | ------- |
| traefik_dashboard_credential | Le crédential utilisé lors de la connexion au dashboard traefik |

___
- Initialize using 

```
$ sudo make init-swarm-manager ARGS=""
```

- Connect using

```
make sh-swarm-manager
```

### swarm worker

Noeud worker du cluster actif swarm, joint automatiquement le swarm, via configuration.

**Variables d'environnement** 

|     | Valeur |
| -------- | ------- |
| AUTHORIZED_KEY | la clé de l'utilisateur (admin) pour connection ssh à l'instance (exemple : voir [`.env.example`](/.env.example)) |
| SWARM_TOKEN | le token swarm pour joindre le cluster swarm (exemple : voir [`.env.example`](/.env.example)) |
| SWARM_WORKER_IP_ADDRESS | L'ip (privée) du worker (exemple : voir [`.env.example`](/.env.example)) |

**Caractéristiques technique**

RAM : 2go
cpu : 2cpu
os : basé sur [debian 13](https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2)
disk : 20go (essentiellement pour les logs, les volumes sont externalisés via NFS @TODO)

___
- Initialize using 

```
$ sudo make init-swarm-worker ARGS=""
```

- Connect using

```
make sh-swarm-worker
```