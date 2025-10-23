# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository provides tools to set up a multi-node Kubernetes cluster for development purposes using Vagrant, VirtualBox, and Ansible. It creates a production-like environment (1 master + 2 worker nodes) that can run on your local machine.

**Current Configuration:**
- Kubernetes Version: 1.34.1
- Container Runtime: containerd
- Network Plugin: Calico
- Base Image: bento/ubuntu-24.04
- VM Resources: 5GB RAM, 2 CPUs per node
- Network: 192.168.56.0/21 (master: 192.168.56.10, workers: 192.168.56.21-22)

## Essential Commands

### Cluster Management
```bash
# Validate setup before starting
./validate.sh

# Start the cluster
vagrant up

# Stop the cluster (preserve state)
vagrant halt

# Destroy cluster completely
vagrant destroy -f

# Check cluster status
vagrant status

# SSH into nodes
vagrant ssh k8s-cp
vagrant ssh node-1
vagrant ssh node-2
```

### Using Make
```bash
make help          # Show all available targets
make setup         # Install prerequisites
make validate      # Validate setup and prerequisites
make up            # Start the cluster
make down          # Stop the cluster
make destroy       # Destroy the cluster
make status        # Show cluster status
make test          # Run all tests
make ssh-master    # SSH into master node
make ssh-node1     # SSH into worker node 1
make ssh-node2     # SSH into worker node 2
```

### Testing
```bash
# Run all tests
./tests/test_cluster.sh
make test

# Run specific test categories
./tests/test_networking.sh    # Network connectivity and pod communication
./tests/test_storage.sh       # Storage and volume functionality
./tests/test_services.sh      # Service discovery and load balancing
make test-networking
make test-storage
make test-services

# Clean up test resources
make clean
```

### Validation Options
```bash
./validate.sh --setup-only      # Only validate prerequisites, skip cluster tests
./validate.sh --cluster-only    # Only run cluster tests, skip setup validation
./validate.sh --skip-vagrant    # Skip Vagrant-specific validations (useful for CI/CD)
```

## Architecture

### Provisioning Flow

1. **Vagrantfile** defines the cluster topology:
   - Creates VMs using VirtualBox provider
   - Configures private networking (192.168.56.0/24)
   - Runs shell scripts for initial setup (apt.sh, 126.sh, 1262.sh)
   - Installs security tools (Trivy, Falco) on master
   - Triggers Ansible playbooks for Kubernetes setup

2. **Shell Scripts** (`scripts/`):
   - `apt.sh`: Updates package manager
   - `126.sh`, `1262.sh`: Kernel/system configuration
   - `c.sh`: Final configuration steps
   - `install-trivy.sh`, `install-falco.sh`: Security tooling
   - `good-k8s-bash.sh`: Bash configuration for kubectl aliases

3. **Ansible Playbooks** (`kubernetes-setup/`):
   - `master-playbook.yml`: Initializes the control plane
     - Installs Docker, containerd, kubelet, kubeadm, kubectl (1.34.1)
     - Runs `kubeadm init` with API server at 192.168.56.10
     - Installs Calico network plugin (via tigera-operator.yaml and custom-resources.yaml)
     - Generates join command for worker nodes
   - `node-playbook.yml`: Sets up worker nodes
     - Installs same container runtime and Kubernetes binaries
     - Joins the cluster using the generated join command

4. **Network Plugin Files** (`kubernetes-setup/`):
   - `tigera-operator.yaml`: Calico operator installation
   - `custom-resources.yaml`: Calico CRDs and configuration
   - `calico.yaml`, `kube-flannel.yaml`: Alternative network plugins (not actively used)

### Testing Framework

The testing framework (`tests/`) uses a common helpers library:

- **`helpers.sh`**: Shared functions for all tests
  - `assert_success()`: Test assertions with pass/fail tracking
  - `assert_equals()`: Value comparison assertions
  - `wait_for_condition()`: Polling with timeout for async operations
  - `print_test_summary()`: Test result reporting
  - Kubernetes helper functions: `get_node_count()`, `is_cluster_ready()`, etc.

- **Test Scripts**: Source `helpers.sh` and use standardized assertion/logging functions
  - All tests track TESTS_PASSED, TESTS_FAILED, and FAILED_TESTS arrays
  - Tests clean up resources after completion

### Alternative CKS Setup

Located in `CKS/hands-on/vagrant/`:
- More structured Ansible role-based setup for Certified Kubernetes Security training
- Uses Ubuntu 18.04 (ubuntu/bionic64)
- Different network range (10.18.0.0/24)
- Organized with separate Ansible roles (general, master, worker)
- Started with `make cks-up` or `cd CKS/hands-on/vagrant && vagrant up`

## Development Workflow

### Modifying the Cluster Configuration

**Changing Kubernetes version:**
1. Update version in `kubernetes-setup/master-playbook.yml` (lines 60, 65, 76-78, 85)
2. Update version in `kubernetes-setup/node-playbook.yml` (lines 59, 64, 75-77)
3. Update apt signing key URL and repository URL to match the minor version (v1.XX)
4. Update README.md and CLAUDE.md to reflect new version

**Changing network plugin:**
1. Modify Vagrantfile to copy desired network YAML (line 21-24)
2. Update master-playbook.yml to apply the correct network manifest (lines 93-97)
3. Adjust pod-network-cidr in kubeadm init if needed (line 85)

**Changing VM resources:**
1. Edit Vagrantfile provider configuration (lines 7-10)
2. Consider host machine RAM requirements (16GB recommended for default config)

### Adding New Tests

1. Create new test script in `tests/` directory
2. Source the helpers: `. "$(dirname "$0")/helpers.sh"`
3. Use standardized functions: `assert_success()`, `assert_equals()`, `wait_for_condition()`
4. End with `print_test_summary()`
5. Add target to Makefile
6. Update validate.sh to include the new test

### Working with Provisioning Scripts

**Shell scripts** in `scripts/` run with `run: 'always', privileged: true`:
- They execute on every `vagrant up` or `vagrant provision`
- Write idempotent scripts (safe to run multiple times)
- Use `-f` flags or check for existence before creating/modifying resources

**Ansible playbooks** run once during initial provisioning:
- To re-run: `vagrant destroy -f && vagrant up`
- Or manually: `vagrant provision --provision-with ansible`

## Important Implementation Details

### Network Configuration

- **Pod network CIDR**: 192.168.56.0/21 (configured in kubeadm init)
- **Service CIDR**: Default Kubernetes range (10.96.0.0/12)
- **Node IPs**: Master uses 192.168.56.10, workers use 192.168.56.21+
- **API Server**: Advertised at 192.168.56.10:6443

### containerd Configuration

Both playbooks remove the default containerd config (line 79-80):
```bash
rm -f /etc/containerd/config.toml
sudo systemctl restart containerd
```
This is required for containerd to work properly with Kubernetes 1.34.

### Shared Directories

Vagrantfile syncs directories to master node:
- `yaml/` → `/home/vagrant/yaml/`
- `scripts/` → `/home/vagrant/scripts/`
- `kubernetes-setup/` → `/home/vagrant/kubernetes-setup/`

These are accessible within the master VM for ad-hoc testing.

### Join Command Mechanism

The master playbook generates a join command and saves it to `./join-command` on the host machine (line 102). The node playbook copies this file to worker nodes and executes it (lines 83-86). If you modify this flow, ensure the join command is available when worker nodes provision.

## Common Gotchas

1. **Vagrant provision always runs scripts**: Scripts marked with `run: 'always'` execute on every `vagrant up`. Make them idempotent.

2. **Swap must be disabled**: Both playbooks disable swap (required for kubelet). Don't re-enable it.

3. **Network plugin timing**: The Calico operator takes time to start. Tests use `wait_for_condition()` to handle this.

4. **VirtualBox Guest Additions**: May need updates if you see shared folder errors. The repo includes `kode/cka/ubuntu/vagrant/install-guest-additions.sh`.

5. **API server certificate**: Includes SAN for 192.168.56.10. If you change the master IP, update line 85 in master-playbook.yml.

6. **Running tests before cluster is ready**: Always ensure cluster is up before running tests. Use `./validate.sh --cluster-only` to verify.
