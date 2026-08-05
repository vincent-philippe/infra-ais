init-swarm-worker:
	@./vm/swarm/init.bash --swarm-mode worker --domain-name worker-1 $(ARGS)
init-swarm-manager:
	@./vm/swarm/init.bash --swarm-mode manager --domain-name swarm-1 $(ARGS)
init-harbor:
	@./vm/registry/init.bash --domain-name harbor-1 $(ARGS)

logs-infra:
	virsh console harbor-1 &
	virsh console swarm-1 &
	virsh console worker-1 &
	@wait

delete-infra:
	@read -p "Press any key to confirm delete (Ctrl+C to interrupt)" choice
	@virsh destroy harbor-1 || true
	@virsh undefine harbor-1 --remove-all-storage || true
	@virsh destroy swarm-1 || true
	@virsh undefine swarm-1 --remove-all-storage || true
	@virsh destroy worker-1 || true
	@virsh undefine worker-1 --remove-all-storage || true

sh-swarm-worker:
	@ssh admin@$$(virsh domifaddr worker-1 | grep -oP '192\.\d+\.\d+\.\d+')
sh-swarm-manager:
	@ssh admin@$$(virsh domifaddr swarm-1 | grep -oP '192\.\d+\.\d+\.\d+')
sh-harbor:
	@ssh admin@$$(virsh domifaddr harbor-1 | grep -oP '192\.\d+\.\d+\.\d+')