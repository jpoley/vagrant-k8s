# Testing Guide for Kubernetes 1.34.1 on Ubuntu 24.04

This guide provides step-by-step instructions to test the Vagrant+Ansible Kubernetes cluster deployment.

## Prerequisites Installation

### Install Ansible (Required)

```bash
# For Ubuntu/Debian
sudo apt update && sudo apt install -y ansible

# Verify installation
ansible --version
```

### Verify Other Prerequisites

```bash
# Check Vagrant
vagrant --version
# Expected: Vagrant 2.x or higher

# Check VirtualBox
vboxmanage --version
# Expected: 7.x or higher
```

## Complete Testing Procedure

### Step 1: Clean Up Existing VMs

Before starting, destroy any existing VMs from previous deployments:

```bash
vagrant destroy -f
```

### Step 2: Deploy the Cluster

Start the cluster with the new configuration (Kubernetes 1.34.1 + Ubuntu 24.04):

```bash
vagrant up
```

**Expected behavior:**
- 3 VMs will be created: k8s-master, node-1, node-2
- Ansible will provision each node with Kubernetes 1.34.1
- The master will initialize the cluster with Calico networking
- Worker nodes will join the cluster
- Total time: 15-25 minutes (depending on your hardware and internet speed)

**Watch for:**
- No Ansible errors during provisioning
- Successful `kubeadm init` on master
- Successful `kubeadm join` on workers
- All playbooks completing successfully

### Step 3: Quick Manual Verification

SSH into the master node and verify basic functionality:

```bash
# SSH into master
vagrant ssh k8s-master

# Check Kubernetes version (should be 1.34.x)
kubectl version --short

# Check Ubuntu version (should be 24.04)
lsb_release -a

# Check nodes (should show 3 nodes, all Ready)
kubectl get nodes -o wide

# Check system pods (should all be Running)
kubectl get pods --all-namespaces

# Exit master node
exit
```

### Step 4: Run Comprehensive Deployment Test

Run the automated end-to-end test that validates everything:

```bash
make test-deployment
```

**Or manually:**
```bash
./test_deployment.sh
```

**This test validates:**
1. ✅ Cluster accessibility (VMs are running)
2. ✅ Kubernetes version is 1.34.x
3. ✅ All nodes are running Ubuntu 24.04
4. ✅ All 3 nodes are present and Ready
5. ✅ System pods are running
6. ✅ Calico network plugin is operational
7. ✅ **Nginx deployment and web server connectivity**
8. ✅ Additional cluster tests

**Expected output:**
```
=====================================
  ALL TESTS PASSED! 🎉
=====================================

Cluster Configuration:
  - Kubernetes: 1.34.1
  - OS: Ubuntu 24.04 LTS
  - Nodes: 3 (1 master + 2 workers)
  - Network: Calico
  - Container Runtime: containerd

The cluster is fully functional and ready for use!
```

### Step 5: Run Individual Tests (Optional)

You can also run specific tests:

```bash
# Test nginx deployment and web connectivity
make test-nginx

# Test cluster functionality
make test-cluster

# Test networking
make test-networking

# Test storage
make test-storage

# Test services
make test-services
```

## What the Nginx Test Does

The nginx deployment test (`test_nginx_deployment.sh`) performs comprehensive validation:

1. **Deploys nginx** with 2 replicas
2. **Creates a NodePort service** to expose nginx
3. **Verifies pods are running** in the correct state
4. **Tests ClusterIP connectivity** using curl from a test pod
5. **Verifies HTTP 200 response** from nginx
6. **Validates nginx welcome page** content
7. **Tests direct pod connectivity** via pod IP
8. **Verifies service endpoints** (load balancing)
9. **Tests DNS resolution** for service names
10. **Tests HTTP via DNS name** (e.g., nginx-test-service.default.svc.cluster.local)
11. **Scales deployment** to 3 replicas and verifies
12. **Cleans up** all test resources

This ensures:
- Pod networking works correctly
- Service discovery works
- DNS resolution works
- Load balancing works
- HTTP traffic can flow through the cluster
- The web server is actually accessible and responding

## Troubleshooting

### If Ansible is not found

```bash
sudo apt update && sudo apt install -y ansible
```

### If deployment hangs or fails

Check the Vagrant logs:
```bash
vagrant up --debug
```

Check specific VM logs:
```bash
vagrant ssh k8s-master -c "journalctl -u kubelet -n 100"
```

### If tests fail

1. Check cluster status:
   ```bash
   vagrant ssh k8s-master -c "kubectl get nodes"
   vagrant ssh k8s-master -c "kubectl get pods --all-namespaces"
   ```

2. Check for errors in pods:
   ```bash
   vagrant ssh k8s-master -c "kubectl describe pod <pod-name> -n <namespace>"
   ```

3. Check Calico status:
   ```bash
   vagrant ssh k8s-master -c "kubectl get pods -n calico-system"
   vagrant ssh k8s-master -c "kubectl get pods -n tigera-operator"
   ```

### Clean up and retry

If something goes wrong:
```bash
# Destroy everything
vagrant destroy -f

# Remove the join command
rm -f join-command

# Start fresh
vagrant up
```

## Expected Timeline

- **Clean destroy:** ~2 minutes
- **Initial VM provisioning:** ~5-10 minutes
- **Ansible playbooks:** ~10-15 minutes
- **Test execution:** ~5 minutes
- **Total:** ~20-30 minutes for a complete test cycle

## Success Criteria

The deployment is successful if:

1. ✅ All 3 VMs are created and running
2. ✅ Kubernetes 1.34.1 is installed on all nodes
3. ✅ Ubuntu 24.04 is running on all nodes
4. ✅ All nodes show status "Ready"
5. ✅ All system pods are "Running"
6. ✅ Calico network plugin is operational
7. ✅ Nginx can be deployed and is accessible
8. ✅ HTTP requests to nginx return 200 OK
9. ✅ Service DNS resolution works
10. ✅ Pod-to-pod networking works

## Quick Command Reference

```bash
# Install prerequisites
sudo apt install -y ansible

# Clean slate
vagrant destroy -f

# Deploy cluster
vagrant up

# Run comprehensive test
make test-deployment

# Run individual tests
make test-nginx
make test-cluster

# Access nodes
vagrant ssh k8s-master
vagrant ssh node-1
vagrant ssh node-2

# Check status
vagrant status
make status

# Clean up
vagrant destroy -f
```

## Files Modified for 1.34.1 + Ubuntu 24.04

- `Vagrantfile` - Updated to Ubuntu 24.04 (noble)
- `kubernetes-setup/master-playbook.yml` - Updated to K8s 1.34.1, Ubuntu 24.04 repos
- `kubernetes-setup/node-playbook.yml` - Updated to K8s 1.34.1, Ubuntu 24.04 repos
- `README.md` - Updated version documentation
- `CLAUDE.md` - Updated version documentation

## New Test Files

- `tests/test_nginx_deployment.sh` - Comprehensive nginx deployment and connectivity test
- `test_deployment.sh` - End-to-end deployment validation script
- `TESTING.md` - This file
