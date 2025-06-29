# vagrant-k8s
Kubernetes Vagrant with VirtualBox 
Here is a view of it running: https://asciinema.org/a/DQdPRwmqW1P4jdHVHkhcplvGi

## Objective
This repository provides the tools to set up a multi-node Kubernetes cluster for development purposes using Vagrant and Ansible. This setup provides a production-like cluster that can be set up on your local machine.

## Why do we require multi node cluster setup?
Multi-node Kubernetes clusters offer a production-like environment which has various advantages. Even though Minikube provides an excellent platform for getting started, it doesn't provide the opportunity to work with multi-node clusters which can help solve problems or bugs that are related to application design and architecture. For instance, Ops can reproduce an issue in a multi-node cluster environment, Testers can deploy multiple versions of an application for executing test cases and verifying changes. These benefits enable teams to resolve issues faster which make them more agile.

## Why use Vagrant and Ansible?
Vagrant is a tool that will allow us to create a virtual environment easily and it eliminates pitfalls that cause the works-on-my-machine phenomenon. It can be used with multiple providers such as Oracle VirtualBox, VMware, Docker, and so on. It allows us to create a disposable environment by making use of configuration files.

Ansible is an infrastructure automation engine that automates software configuration management. It is agentless and allows us to use SSH keys for connecting to remote machines. Ansible playbooks are written in YAML and offer inventory management in simple text files.

## Prerequisites
- **Vagrant** should be installed on your machine. Installation binaries can be found [here](https://www.vagrantup.com/downloads).
- **Oracle VirtualBox** can be used as a Vagrant provider or make use of similar providers as described in Vagrant's [official documentation](https://www.vagrantup.com/docs/providers).
- **Ansible** should be installed on your machine. Refer to the [Ansible installation guide](https://docs.ansible.com/ansible/latest/installation_guide/index.html) for platform-specific installation.

## Why does this exist? 
It's an alternative to a more true virtualized multinode cluster for playing and learning, since most cloud providers charge $.10/hr for their k8s control planes, and sometimes minikube isn't enough. Feedback welcome.

## Current Configuration
- **Kubernetes Version:** 1.28.2 (LTS)
- **Container Runtime:** containerd
- **Network Plugin:** Calico
- **Nodes:** 1 master + 2 worker nodes
- **VM Resources:** 5GB RAM, 2 CPU per node

## Quick Start

### 1. Clone the repository
```bash
git clone https://github.com/jpoley/vagrant-k8s.git
cd vagrant-k8s
```

### 2. Validate your setup (recommended)
```bash
./validate.sh
```

### 3. Start the cluster
```bash
vagrant up
```

### 4. Access the cluster
```bash
# SSH into the master node
vagrant ssh k8s-master

# Check cluster status
kubectl get nodes
kubectl get pods --all-namespaces
```

### 5. Run comprehensive tests
```bash
# Run all tests
./tests/test_cluster.sh

# Run specific test categories
./tests/test_networking.sh
./tests/test_storage.sh
./tests/test_services.sh
```

## Testing Framework

This repository includes a comprehensive testing framework to validate the Kubernetes cluster functionality:

- **`validate.sh`** - Main validation script that checks prerequisites and configurations
- **`tests/test_cluster.sh`** - Core cluster functionality tests
- **`tests/test_networking.sh`** - Network connectivity and pod communication tests  
- **`tests/test_storage.sh`** - Storage and volume functionality tests
- **`tests/test_services.sh`** - Service discovery and load balancing tests

### Running Tests

```bash
# Validate setup before starting
./validate.sh --setup-only

# Validate running cluster (requires cluster to be up)
./validate.sh --cluster-only

# Run all validations
./validate.sh
```

## VM Provider Flexibility

The setup can be easily adapted to use different VM providers:

### VMware
```ruby
config.vm.provider "vmware_desktop" do |v|
  v.memory = 5000 
  v.cpus = 2
end
```

### Hyper-V
```ruby
config.vm.provider "hyperv" do |v|
  v.memory = 5000
  v.cpus = 2
end
```

### Libvirt
```ruby
config.vm.provider "libvirt" do |v|
  v.memory = 5000
  v.cpus = 2
end
```

## Alternative Configurations

### CKS (Certified Kubernetes Security) Setup
Located in `CKS/hands-on/vagrant/`, this provides a more structured Ansible role-based setup:

```bash
cd CKS/hands-on/vagrant/
vagrant up
```

## Troubleshooting

### Common Issues

1. **VirtualBox Guest Additions**: Ensure VirtualBox Guest Additions are up to date
2. **Memory Issues**: If you have less than 16GB RAM, consider reducing VM memory in Vagrantfile
3. **Network Issues**: Check that the private network range doesn't conflict with your local network

### Logs and Debugging

```bash
# Check Vagrant logs
vagrant up --debug

# Check VM status
vagrant status

# SSH into nodes for debugging
vagrant ssh k8s-master
vagrant ssh node-1
vagrant ssh node-2

# Check Kubernetes logs
kubectl logs -n kube-system <pod-name>
journalctl -u kubelet
```

## Cleaning Up

```bash
# Stop and remove VMs
vagrant destroy -f

# Clean up any test resources (if cluster is running)
kubectl delete namespace test-namespace --ignore-not-found=true
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run the validation tests: `./validate.sh`
5. Submit a pull request

## License

This project is licensed under the terms specified in the LICENSE file.