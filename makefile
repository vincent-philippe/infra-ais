init-swarm-worker:
	@./vm/swarm/init.bash --swarm-mode worker --domain-name worker-1 $(ARGS)
init-swarm-manager:
	@./vm/swarm/init.bash --swarm-mode manager --domain-name swarm-1 $(ARGS)
init-harbor:
	@./vm/registry/init.bash --domain-name harbor-1 $(ARGS)