.DEFAULT_GOAL := help

help: ## Affiche cette aide
	@echo "Usage: make [target]\n\n"
	@echo "Targets:"
	@grep -hE '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	  | sort \
	  | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

init-ceph-node-master: ## Crée un noeud ceph - make init-ceph-node-master NAME=ceph-1 IP=10.0.120.6/24 IP_INTERNAL_CLUSTER=10.0.1.6/24 CLUSTER_NETWORK=10.0.1.0/24
	@./vm/ceph/init.bash --domain-name $(NAME) --ip-address $(IP) --ip-internal-address $(IP_INTERNAL_CLUSTER) --net-cluster $(CLUSTER_NETWORK)
init-ceph-node: ## Créé un noeud qui rejoint le cluster ciblé par 'ip-master' - make init-ceph-node NAME=ceph-2 IP=10.0.120.7/24 IP_INTERNAL_CLUSTER=10.0.1.7/24 IP_MASTER=10.0.120.6/24
	@./vm/ceph/init.bash --domain-name $(NAME) --ip-address $(IP) --ip-internal-address $(IP_INTERNAL_CLUSTER) --ip-master $(IP_MASTER)
init-swarm-worker: ## Crée une VM worker swarm - make init-swarm-worker NAME=worker-1 IP=192.168.122.11/27 SERVER_IP=10.0.130.11/24 CEPH_IP_ADDRESS=10.0.120.6/24
	@./vm/swarm/init.bash --swarm-mode worker --domain-name $(NAME) --ip-address $(IP) --ip-server-address $(SERVER_IP) --ceph-ip-address $(CEPH_IP_ADDRESS)
init-swarm-manager: ## Crée une VM manager swarm - make init-swarm-manager NAME=swarm-1 IP=192.168.122.10/27 SERVER_IP=10.0.130.10/24 KEEP_ALIVED_CONF=./keepalived.conf CEPH_IP_ADDRESS=10.0.120.6/24
	@./vm/swarm/init.bash --swarm-mode manager --domain-name $(NAME) --ip-address $(IP) --ip-server-address $(SERVER_IP) --keep-alived-conf $(KEEP_ALIVED_CONF)  --ceph-ip-address $(CEPH_IP_ADDRESS)
init-harbor: ## Crée la VM Harbor - make init-harbor NAME=harbor-1 IP=10.0.110.14/24
	@./vm/registry/init.bash --domain-name $(NAME) --ip-address $(IP)
init-opnsense: ## Crée la VM OPNsense (pare-feu/routeur) - make init-opnsense SWARM_VIP_ADDRESS=10.0.130.13
	@./vm/opnsense/init.bash --swarm-vip-address $(SWARM_VIP_ADDRESS)
init-traefik: ## Déploie le stack traefik sur le manager swarm - make init-traefik SWARM_IP=192.168.122.10
	ssh admin@$(SWARM_IP) " \
		sudo docker stack deploy -c /docker-compose-traefik.yml traefik \
	"

deploy-harbor-cert-to-swarm: ## make deploy-harbor-cert-to-swarm HARBOR_IP=10.0.110.14 SWARM_IP="192.168.122.10 192.168.122.11 192.168.122.12"
	@set -a && . ./.env && set +a && \
	scp admin@$(HARBOR_IP):/opt/harbor/certs/server.crt /tmp/$${HARBOR_DOMAIN_NAME}-rootCA.crt && \
	for NODE_IP in $(SWARM_IP); do \
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

deploy-game-app: ## Build, push et déploie la stack gameapp sur le swarm - make deploy-game-app SWARM_IP=192.168.122.10
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


delete-infra: ## Détruit l'infra (harbor-1, swarm-1, swarm-2)
	@read -p "Press any key to confirm delete (Ctrl+C to interrupt)" choice
	@virsh destroy harbor-1 || true
	@virsh undefine harbor-1 --remove-all-storage || true
	@virsh destroy swarm-1 || true
	@virsh undefine swarm-1 --remove-all-storage || true
	@virsh destroy swarm-2 || true
	@virsh undefine swarm-2 --remove-all-storage || true
