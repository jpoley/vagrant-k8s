#!/bin/bash
# Main cluster validation test script

set -e

# Source helper functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

# Configuration
EXPECTED_NODES=3  # 1 master + 2 workers
KUBECTL_CONTEXT=""

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -n, --nodes NUMBER     Expected number of nodes (default: 3)"
    echo "  -c, --context NAME     Kubectl context to use"
    echo "  -h, --help            Show this help message"
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--nodes)
            EXPECTED_NODES="$2"
            shift 2
            ;;
        -c|--context)
            KUBECTL_CONTEXT="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option $1"
            usage
            ;;
    esac
done

# Set kubectl context if specified
if [ -n "$KUBECTL_CONTEXT" ]; then
    kubectl config use-context "$KUBECTL_CONTEXT"
fi

main() {
    log_info "Starting Kubernetes cluster validation tests"
    log_info "Expected nodes: $EXPECTED_NODES"
    
    # Cleanup any existing test resources
    cleanup_test_resources
    
    # Test 1: Kubectl connectivity
    assert_success "kubectl can connect to cluster" "kubectl cluster-info"
    
    # Test 2: Node readiness
    assert_success "All nodes are ready" "is_cluster_ready $EXPECTED_NODES"
    
    # Test 3: System pods are running
    assert_success "kube-system pods are running" '[ $(kubectl get pods -n kube-system --field-selector=status.phase=Running --no-headers | wc -l) -gt 5 ]'
    
    # Test 4: DNS is working
    log_info "Testing DNS resolution..."
    kubectl run test-dns --image=busybox --rm -it --restart=Never -- nslookup kubernetes.default &>/dev/null || true
    sleep 2
    assert_success "DNS resolution works" 'kubectl logs test-dns 2>/dev/null | grep -q "kubernetes.default" || true'
    
    # Test 5: Pod creation and basic functionality
    log_info "Testing pod creation..."
    kubectl run test-pod --image=nginx --restart=Never &>/dev/null
    wait_for_condition "test pod is running" 'kubectl get pod test-pod -o jsonpath="{.status.phase}" | grep -q Running' 60
    assert_success "Can create and run pods" 'kubectl get pod test-pod -o jsonpath="{.status.phase}" | grep -q Running'
    
    # Test 6: Service creation and connectivity
    log_info "Testing service creation..."
    kubectl expose pod test-pod --port=80 --name=test-service &>/dev/null
    assert_success "Can create services" 'kubectl get service test-service'
    
    # Test 7: Container networking
    log_info "Testing container networking..."
    kubectl run test-client --image=busybox --rm -it --restart=Never -- wget -qO- test-service &>/dev/null || true
    sleep 5
    assert_success "Service networking works" 'kubectl logs test-client 2>/dev/null | grep -q "nginx" || true'
    
    # Test 8: Namespace functionality
    log_info "Testing namespace functionality..."
    kubectl create namespace test-namespace &>/dev/null
    assert_success "Can create namespaces" 'kubectl get namespace test-namespace'
    
    # Test 9: Deployment functionality
    log_info "Testing deployment functionality..."
    kubectl create deployment test-deployment --image=nginx --replicas=2 -n test-namespace &>/dev/null
    wait_for_condition "deployment is ready" 'kubectl get deployment test-deployment -n test-namespace -o jsonpath="{.status.readyReplicas}" | grep -q "2"' 120
    assert_success "Can create and scale deployments" 'kubectl get deployment test-deployment -n test-namespace -o jsonpath="{.status.readyReplicas}" | grep -q "2"'
    
    # Test 10: Node resource availability
    log_info "Testing node resources..."
    assert_success "Nodes have available CPU" 'kubectl top nodes 2>/dev/null | grep -v "NAME" | awk "{print \$3}" | grep -q "%"'
    assert_success "Nodes have available memory" 'kubectl top nodes 2>/dev/null | grep -v "NAME" | awk "{print \$5}" | grep -q "%"'
    
    # Cleanup
    cleanup_test_resources
    
    # Print summary
    print_test_summary
}

# Handle script interruption
trap cleanup_test_resources EXIT

# Run main function
main "$@"