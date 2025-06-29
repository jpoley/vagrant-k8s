.PHONY: help validate up down destroy status test test-cluster test-networking test-storage test-services clean

# Default target
help:
	@echo "Available targets:"
	@echo "  validate        - Validate setup and prerequisites"
	@echo "  up              - Start the Kubernetes cluster"
	@echo "  down            - Stop the cluster (suspend VMs)"
	@echo "  destroy         - Completely destroy the cluster"
	@echo "  status          - Show cluster status"
	@echo "  test            - Run all tests"
	@echo "  test-cluster    - Run cluster functionality tests"
	@echo "  test-networking - Run networking tests"
	@echo "  test-storage    - Run storage tests"
	@echo "  test-services   - Run service tests"
	@echo "  clean           - Clean up test resources"
	@echo "  ssh-master      - SSH into master node"
	@echo "  ssh-node1       - SSH into worker node 1"
	@echo "  ssh-node2       - SSH into worker node 2"

validate:
	./validate.sh

up:
	vagrant up

down:
	vagrant halt

destroy:
	vagrant destroy -f

status:
	vagrant status

test: test-cluster test-networking test-storage test-services

test-cluster:
	./tests/test_cluster.sh

test-networking:
	./tests/test_networking.sh

test-storage:
	./tests/test_storage.sh

test-services:
	./tests/test_services.sh

clean:
	-kubectl delete namespace test-namespace --ignore-not-found=true
	-kubectl delete pod test-pod --ignore-not-found=true
	-kubectl delete service test-service --ignore-not-found=true
	-kubectl delete deployment test-deployment --ignore-not-found=true

ssh-master:
	vagrant ssh k8s-master

ssh-node1:
	vagrant ssh node-1

ssh-node2:
	vagrant ssh node-2

# Alternative CKS setup targets
cks-up:
	cd CKS/hands-on/vagrant && vagrant up

cks-down:
	cd CKS/hands-on/vagrant && vagrant halt

cks-destroy:
	cd CKS/hands-on/vagrant && vagrant destroy -f

cks-status:
	cd CKS/hands-on/vagrant && vagrant status