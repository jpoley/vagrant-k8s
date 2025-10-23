#!/bin/bash
# End-to-end deployment test for Kubernetes 1.34.1 on Ubuntu 24.04
# This script validates the complete cluster deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_header() {
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${BLUE} $1${NC}"
    echo -e "${BLUE}=====================================${NC}"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_fail() {
    echo -e "${RED}[✗]${NC} $1"
}

ERRORS=0

# Test 1: Verify cluster is accessible
log_header "Test 1: Cluster Accessibility"
if vagrant status k8s-master | grep -q "running"; then
    log_success "Vagrant VMs are running"
else
    log_fail "Vagrant VMs are not running"
    ((ERRORS++))
    exit 1
fi

# Test 2: Verify Kubernetes version from master node
log_header "Test 2: Kubernetes Version Verification"
K8S_VERSION=$(vagrant ssh k8s-master -c "kubectl version --short 2>/dev/null | grep 'Server Version' | awk '{print \$3}'" 2>/dev/null | tr -d '\r')
log_info "Kubernetes version: ${K8S_VERSION}"
if [[ "${K8S_VERSION}" == *"1.34"* ]]; then
    log_success "Kubernetes 1.34.x is running"
else
    log_fail "Expected Kubernetes 1.34.x, got ${K8S_VERSION}"
    ((ERRORS++))
fi

# Test 3: Verify Ubuntu version on all nodes
log_header "Test 3: Ubuntu Version Verification"

echo "Checking master node..."
MASTER_OS=$(vagrant ssh k8s-master -c "lsb_release -d" 2>/dev/null | grep Description | tr -d '\r')
log_info "Master: ${MASTER_OS}"
if echo "${MASTER_OS}" | grep -q "24.04"; then
    log_success "Master node running Ubuntu 24.04"
else
    log_fail "Master node not running Ubuntu 24.04"
    ((ERRORS++))
fi

for i in 1 2; do
    echo "Checking worker node-${i}..."
    NODE_OS=$(vagrant ssh node-${i} -c "lsb_release -d" 2>/dev/null | grep Description | tr -d '\r')
    log_info "Node-${i}: ${NODE_OS}"
    if echo "${NODE_OS}" | grep -q "24.04"; then
        log_success "Worker node-${i} running Ubuntu 24.04"
    else
        log_fail "Worker node-${i} not running Ubuntu 24.04"
        ((ERRORS++))
    fi
done

# Test 4: Verify cluster health
log_header "Test 4: Cluster Health Check"

# Check nodes
NODE_COUNT=$(vagrant ssh k8s-master -c "kubectl get nodes --no-headers 2>/dev/null | wc -l" 2>/dev/null | tr -d '\r')
log_info "Total nodes: ${NODE_COUNT}"
if [ "${NODE_COUNT}" -eq 3 ]; then
    log_success "All 3 nodes are present"
else
    log_fail "Expected 3 nodes, found ${NODE_COUNT}"
    ((ERRORS++))
fi

# Check node status
READY_NODES=$(vagrant ssh k8s-master -c "kubectl get nodes --no-headers 2>/dev/null | grep -c Ready" 2>/dev/null | tr -d '\r')
log_info "Ready nodes: ${READY_NODES}"
if [ "${READY_NODES}" -eq 3 ]; then
    log_success "All 3 nodes are Ready"
else
    log_fail "Expected 3 Ready nodes, found ${READY_NODES}"
    ((ERRORS++))
fi

# Show node details
echo ""
log_info "Node details:"
vagrant ssh k8s-master -c "kubectl get nodes -o wide" 2>/dev/null

# Test 5: Verify system pods
log_header "Test 5: System Pods Health Check"

# Check kube-system pods
SYSTEM_PODS=$(vagrant ssh k8s-master -c "kubectl get pods -n kube-system --no-headers 2>/dev/null | wc -l" 2>/dev/null | tr -d '\r')
log_info "kube-system pods: ${SYSTEM_PODS}"

RUNNING_SYSTEM_PODS=$(vagrant ssh k8s-master -c "kubectl get pods -n kube-system --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l" 2>/dev/null | tr -d '\r')
log_info "Running kube-system pods: ${RUNNING_SYSTEM_PODS}"

if [ "${RUNNING_SYSTEM_PODS}" -ge 10 ]; then
    log_success "System pods are running"
else
    log_fail "Not enough system pods running"
    ((ERRORS++))
fi

# Show system pods
echo ""
log_info "System pods status:"
vagrant ssh k8s-master -c "kubectl get pods -n kube-system" 2>/dev/null

# Test 6: Verify Calico network plugin
log_header "Test 6: Calico Network Plugin Check"

CALICO_PODS=$(vagrant ssh k8s-master -c "kubectl get pods -n calico-system --no-headers 2>/dev/null | wc -l" 2>/dev/null | tr -d '\r' || echo "0")
if [ "${CALICO_PODS}" -gt 0 ]; then
    log_success "Calico pods found in calico-system namespace"
    vagrant ssh k8s-master -c "kubectl get pods -n calico-system" 2>/dev/null
else
    # Check tigera-operator namespace
    TIGERA_PODS=$(vagrant ssh k8s-master -c "kubectl get pods -n tigera-operator --no-headers 2>/dev/null | wc -l" 2>/dev/null | tr -d '\r' || echo "0")
    if [ "${TIGERA_PODS}" -gt 0 ]; then
        log_success "Calico pods found in tigera-operator namespace"
        vagrant ssh k8s-master -c "kubectl get pods -n tigera-operator" 2>/dev/null
    else
        log_fail "Calico network plugin pods not found"
        ((ERRORS++))
    fi
fi

# Test 7: Run nginx deployment test
log_header "Test 7: Nginx Deployment and Connectivity Test"
log_info "Copying test script to master node..."
vagrant ssh k8s-master -c "mkdir -p /home/vagrant/tests" 2>/dev/null

# Copy helpers and test script
vagrant scp tests/helpers.sh k8s-master:/home/vagrant/tests/ 2>/dev/null
vagrant scp tests/test_nginx_deployment.sh k8s-master:/home/vagrant/tests/ 2>/dev/null

log_info "Running nginx deployment test..."
if vagrant ssh k8s-master -c "cd /home/vagrant/tests && bash test_nginx_deployment.sh" 2>&1; then
    log_success "Nginx deployment test passed"
else
    log_fail "Nginx deployment test failed"
    ((ERRORS++))
fi

# Test 8: Run existing cluster tests (if they exist)
log_header "Test 8: Additional Cluster Tests"
if [ -f "./tests/test_cluster.sh" ]; then
    log_info "Running cluster tests..."
    vagrant scp tests/test_cluster.sh k8s-master:/home/vagrant/tests/ 2>/dev/null
    if vagrant ssh k8s-master -c "cd /home/vagrant/tests && bash test_cluster.sh" 2>&1; then
        log_success "Cluster tests passed"
    else
        log_fail "Cluster tests failed"
        ((ERRORS++))
    fi
else
    log_info "Skipping - test_cluster.sh not found"
fi

# Final summary
log_header "Test Summary"
if [ ${ERRORS} -eq 0 ]; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  ALL TESTS PASSED! 🎉${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "Cluster Configuration:"
    echo "  - Kubernetes: 1.34.1"
    echo "  - OS: Ubuntu 24.04 LTS"
    echo "  - Nodes: 3 (1 master + 2 workers)"
    echo "  - Network: Calico"
    echo "  - Container Runtime: containerd"
    echo ""
    echo "The cluster is fully functional and ready for use!"
    exit 0
else
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}  TESTS FAILED: ${ERRORS} error(s) found${NC}"
    echo -e "${RED}========================================${NC}"
    exit 1
fi
