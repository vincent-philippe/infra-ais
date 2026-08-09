include .env
export

HARBOR_IP=$(shell echo $(HARBOR_IP_ADDRESS) | cut -d/ -f1)
SWARM_IP=$(shell echo $(SWARM_IP_ADDRESS) | cut -d/ -f1)
WORKER_IP=$(shell echo $(SWARM_WORKER_IP_ADDRESS) | cut -d/ -f1)

init-swarm-worker:
	@./vm/swarm/init.bash --swarm-mode worker --domain-name worker-1 $(ARGS)
init-swarm-manager:
	@./vm/swarm/init.bash --swarm-mode manager --domain-name swarm-1 $(ARGS)
init-harbor:
	@./vm/registry/init.bash --domain-name harbor-1 $(ARGS)


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

deploy-game-app:
	@echo "==> Build images"
	@cd docker/game-app && docker compose build
	@echo "==> Push images to Harbor"
	@cd docker/game-app && docker compose push
	@echo "==> Deploy stack on swarm manager"
	@scp docker/game-app/docker-compose.swarm.yml admin@$(SWARM_IP):/tmp/docker-compose.swarm.yml && \
		ssh admin@$(SWARM_IP) " \
			sudo docker stack deploy --with-registry-auth -c /tmp/docker-compose.swarm.yml gameapp && \
			sudo docker stack services -q gameapp | while read svc; do \
				sudo docker service update --force --with-registry-auth \$$svc; \
			done"


delete-infra:
	@read -p "Press any key to confirm delete (Ctrl+C to interrupt)" choice
	@virsh destroy harbor-1 || true
	@virsh undefine harbor-1 --remove-all-storage || true
	@virsh destroy swarm-1 || true
	@virsh undefine swarm-1 --remove-all-storage || true
	@virsh destroy worker-1 || true
	@virsh undefine worker-1 --remove-all-storage || true

sh-swarm-worker:
	@ssh admin@$(WORKER_IP) $(ARGS)
sh-swarm-manager:
	@ssh admin@$(SWARM_IP) $(ARGS)
sh-harbor:
	@ssh admin@$(HARBOR_IP) $(ARGS)
