Publier l'application : 

```bash
cd docker/game-app && docker compose build && docker compose push
```

Déployer l'application :

```bash
ssh admin@$$(virsh domifaddr swarm-1 | grep -oP '192\.\d+\.\d+\.\d+') && docker stack deploy gameapp -c /data/gameapp/compose.swarm.yml --with-registry-auth
```