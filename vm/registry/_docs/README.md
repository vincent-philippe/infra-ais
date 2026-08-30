### Registry

Registry stockant les images / artifacts docker.

Nous utilisons [harbor](https://github.com/goharbor/harbor), un registry privé auto-hébergable.

Le registre harbor permettra d'héberger les images docker.
Les images sont ensuite pull par le swarm lors du déploiement des stacks.

**Variables d'environnement** 

|     | Valeur |
| -------- | ------- |
| HARBOR_ADMIN_PASSWORD | Le mot de passe admin harbor (également utilisé comme mdp de bdd) (exemple : voir [`.env.example`](/.env.example)) |
| HARBOR_DOMAIN_NAME | Le nom de domaine depuis l'instance harbor est accessible (exemple : voir [`.env.example`](/.env.example)) |

**Caractéristiques technique**

RAM : 3go
cpu : 2cpu
os : basé sur [debian 13](https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2)
disk : 40go (Stockage des images, de la db de vulnérabilité, et des SBOM / Scans de vulnérabilités)

___
- Initialize using

```
$ sudo make init-harbor NAME=harbor-1 IP=10.0.110.14/24
```

- Connect using

```
ssh admin@10.0.110.14
```