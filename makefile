include .env
export

HARBOR_IP=$(shell echo $(HARBOR_IP_ADDRESS) | cut -d/ -f1)
SWARM_IP=$(shell echo $(SWARM_IP_ADDRESS) | cut -d/ -f1)
WORKER_IP=$(shell echo $(SWARM_WORKER_IP_ADDRESS) | cut -d/ -f1)

init-swarm-worker:
	@./vm/swarm/init.bash --swarm-mode worker --domain-name $(ARGS)
init-swarm-manager:
	@./vm/swarm/init.bash --swarm-mode manager --domain-name $(ARGS)
init-harbor:
	@./vm/registry/init.bash --domain-name harbor-1 $(ARGS)
init-traefik:
	ssh admin@$(SWARM_IP) " \
		sudo docker stack deploy -c /docker-compose-traefik.yml traefik \
	"

troubleshoot-swarm-worker:
	@echo "============================================================================"
	@echo "Show all log and status info to troubleshoot a vm failing to boot / startup"
	@echo "============================================================================"
	@make sh-swarm-worker ARGS="sudo cloud-init status --long"
	@make sh-swarm-worker ARGS="sudo cat /var/log/cloud-init-output.log"
	@make sh-swarm-worker ARGS="sudo cat /var/log/cloud-init.log"
troubleshoot-swarm-manager:
	@echo "============================================================================"
	@echo "Show all log and status info to troubleshoot a vm failing to boot / startup"
	@echo "============================================================================"
	@make sh-swarm-manager ARGS="sudo cloud-init status --long"
	@make sh-swarm-manager ARGS="sudo cat /var/log/cloud-init-output.log"
	@make sh-swarm-manager ARGS="sudo cat /var/log/cloud-init.log"
troubleshoot-harbor:
	@echo "============================================================================"
	@echo "Show all log and status info to troubleshoot a vm failing to boot / startup"
	@echo "============================================================================"
	@make sh-harbor ARGS="sudo cloud-init status --long"
	@make sh-harbor ARGS="sudo cat /var/log/cloud-init-output.log"
	@make sh-harbor ARGS="sudo cat /var/log/cloud-init.log"

deploy-harbor-cert-to-swarm:
	@set -a && . ./.env && set +a && \
	scp admin@$(HARBOR_IP):/opt/harbor/certs/server.crt /tmp/$${HARBOR_DOMAIN_NAME}-rootCA.crt && \
	for NODE_IP in $(SWARM_IP) $(WORKER_IP); do \
		echo "==> Deploying Harbor cert to $$NODE_IP" && \
		scp /tmp/$${HARBOR_DOMAIN_NAME}-rootCA.crt admin@$$NODE_IP:/tmp/$${HARBOR_DOMAIN_NAME}-rootCA.crt && \
		ssh admin@$$NODE_IP " \
			sudo sed -i '/$${HARBOR_DOMAIN_NAME}/d' /etc/hosts && \
			echo '$(HARBOR_IP) $${HARBOR_DOMAIN_NAME}' | sudo tee -a /etc/hosts && \
			sudo mkdir -p /usr/local/share/ca-certificates/$${HARBOR_DOMAIN_NAME} && \
			sudo mkdir -p /etc/docker/certs.d/$${HARBOR_DOMAIN_NAME} && \
			sudo cp /tmp/$${HARBOR_DOMAIN_NAME}-rootCA.crt /usr/local/share/ca-certificates/$${HARBOR_DOMAIN_NAME}/rootCA.crt && \
			sudo cp /tmp/$${HARBOR_DOMAIN_NAME}-rootCA.crt /etc/docker/certs.d/$${HARBOR_DOMAIN_NAME}/ca.crt && \
			sudo update-ca-certificates && \
			sudo systemctl restart docker"; \
	done && \
	rm /tmp/$${HARBOR_DOMAIN_NAME}-rootCA.crt

# Traefik tourne désormais en `mode: global` : chaque nœud a besoin en local des
# fichiers montés en bind (conf + certificat), que le cloud-init n'écrit que sur
# le manager. Le certificat est lu depuis le manager puis recopié à l'identique
# partout, pour que tous les nœuds servent le même cert derrière la VIP.
deploy-traefik-conf:
	@set -a && . ./.env && set +a && \
	envsubst < vm/swarm/manager/traefik/conf/traefik.toml > /tmp/traefik.toml && \
	ssh admin@$(SWARM_IP) 'sudo cat /etc/traefik/certs/local.crt' > /tmp/traefik-local.crt && \
	ssh admin@$(SWARM_IP) 'sudo cat /etc/traefik/certs/local.key' > /tmp/traefik-local.key && \
	for NODE_IP in $(SWARM_IP) $(WORKER_IP); do \
		echo "==> Deploying traefik conf to $$NODE_IP" && \
		scp -q /tmp/traefik.toml /tmp/traefik-local.crt /tmp/traefik-local.key \
			vm/swarm/manager/traefik/conf/tls.yml admin@$$NODE_IP:/tmp/ && \
		ssh admin@$$NODE_IP " \
			sudo mkdir -p /etc/traefik/conf /etc/traefik/certs && \
			sudo cp /tmp/traefik.toml /etc/traefik/conf/traefik.toml && \
			sudo cp /tmp/tls.yml /etc/traefik/tls.yml && \
			sudo cp /tmp/traefik-local.crt /etc/traefik/certs/local.crt && \
			sudo cp /tmp/traefik-local.key /etc/traefik/certs/local.key && \
			sudo chmod 0644 /etc/traefik/conf/traefik.toml /etc/traefik/tls.yml /etc/traefik/certs/local.crt && \
			sudo chmod 0600 /etc/traefik/certs/local.key && \
			rm -f /tmp/traefik.toml /tmp/tls.yml /tmp/traefik-local.crt /tmp/traefik-local.key"; \
	done && \
	rm -f /tmp/traefik.toml /tmp/traefik-local.crt /tmp/traefik-local.key

deploy-traefik: deploy-traefik-conf
	@echo "==> Deploy traefik stack on swarm manager"
	@set -a && . ./.env && set +a && \
	envsubst < vm/swarm/manager/traefik/docker-compose-swarm.yml > /tmp/docker-compose-traefik.yml && \
	scp -q /tmp/docker-compose-traefik.yml admin@$(SWARM_IP):/tmp/docker-compose-traefik.yml && \
	ssh admin@$(SWARM_IP) 'sudo docker stack deploy -c /tmp/docker-compose-traefik.yml traefik' && \
	rm -f /tmp/docker-compose-traefik.yml

deploy-game-app:
	@echo "==> Build images"
	@cd docker/game-app && docker compose build
	@echo "==> Push images to Harbor"
	@cd docker/game-app && docker compose push
	@echo "==> Deploy stack on swarm manager"
	@ssh admin@$(SWARM_IP) 'mkdir -p /tmp/gameapp'
	@scp docker/game-app/docker-compose.swarm.yml admin@$(SWARM_IP):/tmp/gameapp/docker-compose.swarm.yml
	@scp docker/game-app/.env.swarm admin@$(SWARM_IP):/tmp/gameapp/.env.swarm
	@ssh admin@$(SWARM_IP) ' \
		set -a && . /tmp/gameapp/.env.swarm && set +a && \
		envsubst < /tmp/gameapp/docker-compose.swarm.yml > /tmp/gameapp/docker-compose.swarm.yml.cp && \
		sudo docker stack deploy --with-registry-auth -c /tmp/gameapp/docker-compose.swarm.yml.cp gameapp && \
		sudo docker stack services -q gameapp | while read svc; do \
			sudo docker service update --force --with-registry-auth $$svc; \
		done'


delete-infra:
	@read -p "Press any key to confirm delete (Ctrl+C to interrupt)" choice
	@virsh destroy harbor-1 || true
	@virsh undefine harbor-1 --remove-all-storage || true
	@virsh destroy swarm-1 || true
	@virsh undefine swarm-1 --remove-all-storage || true
	@virsh destroy swarm-2 || true
	@virsh undefine swarm-2 --remove-all-storage || true

sh-swarm-worker:
	@ssh admin@$(WORKER_IP) $(ARGS)
sh-swarm-manager:
	@ssh admin@$(SWARM_IP) $(ARGS)
sh-harbor:
	@ssh admin@$(HARBOR_IP) $(ARGS)
