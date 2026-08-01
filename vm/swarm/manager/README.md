noeud manager du cluster actif swarm

4go / 2cpu

basé sur debian 13

Disque pool = default (`/var/lib/libvirt/images`)

Contient docker swarm initialisé (node manager)

launch using 

```
make init-swarm-manager
```

connect using

```
ssh admin@$(virsh domifaddr swarm-1 | grep 192. | cut -d " " -f 20 | cut -d "/" -f 1)
```