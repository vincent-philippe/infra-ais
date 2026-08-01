COMMAND_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))                                                                                                                
$(eval $(COMMAND_ARGS):;@:)

init-swarm-manager:
	@chmod +x ./vm/swarm/manager/init-swarm.bash
	@./vm/swarm/manager/init-swarm.bash
