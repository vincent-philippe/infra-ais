## Déploiement

Publier l'application : 

```bash
cd docker/game-app && docker compose build && docker compose push
```

Déployer l'application :

```bash
ssh admin@$$(virsh domifaddr swarm-1 | grep -oP '192\.\d+\.\d+\.\d+')
```
```bash
set -a && \
source /data/gameapp/.env.swarm && \
set +a && \
envsubst < /data/gameapp/compose.swarm.yml > /data/gameapp/compose.swarm.yml.cp && \
docker stack deploy gameapp -c /data/gameapp/compose.swarm.yml.cp --with-registry-auth && \
rm -rf 
```

## Secrets

Les secrets suivant doivent être définis

```bash
gameapp_postgres_user
gameapp_postgres_password
gameapp_database_url
```

## Network

Le network suivant doit être créé en overlay (si plus d'un replica)

```bash
game_app_intra
```