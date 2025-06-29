#!/bin/bash
# Network connectivity and pod communication tests

set -e

# Source helper functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

main() {
    log_info "Starting network connectivity tests"
    
    # Cleanup any existing test resources
    cleanup_test_resources
    
    # Test 1: Pod-to-pod communication within same node
    log_info "Testing pod-to-pod communication..."
    kubectl run net-test-1 --image=nginx --restart=Never &>/dev/null
    kubectl run net-test-2 --image=busybox --restart=Never -- sleep 3600 &>/dev/null
    
    wait_for_condition "nginx pod is running" 'kubectl get pod net-test-1 -o jsonpath="{.status.phase}" | grep -q Running' 60
    wait_for_condition "busybox pod is running" 'kubectl get pod net-test-2 -o jsonpath="{.status.phase}" | grep -q Running' 60
    
    # Get nginx pod IP
    local nginx_ip=$(kubectl get pod net-test-1 -o jsonpath='{.status.podIP}')
    assert_success "Can retrieve pod IP" '[ -n "$nginx_ip" ]'
    
    # Test connectivity
    kubectl exec net-test-2 -- wget -qO- "$nginx_ip" &>/dev/null || true
    sleep 2
    assert_success "Pod-to-pod networking works" 'kubectl exec net-test-2 -- wget -qO- "'$nginx_ip'" 2>/dev/null | grep -q nginx'
    
    # Test 2: Service discovery via DNS
    log_info "Testing service discovery..."
    kubectl expose pod net-test-1 --port=80 --name=net-test-service &>/dev/null
    sleep 5
    assert_success "Service DNS resolution works" 'kubectl exec net-test-2 -- nslookup net-test-service 2>/dev/null | grep -q "net-test-service"'
    
    # Test 3: Service connectivity
    assert_success "Service connectivity works" 'kubectl exec net-test-2 -- wget -qO- net-test-service 2>/dev/null | grep -q nginx'
    
    # Test 4: Cross-namespace networking
    log_info "Testing cross-namespace networking..."
    kubectl create namespace net-test-ns &>/dev/null
    kubectl run net-test-3 --image=nginx --restart=Never -n net-test-ns &>/dev/null
    wait_for_condition "cross-namespace pod is running" 'kubectl get pod net-test-3 -n net-test-ns -o jsonpath="{.status.phase}" | grep -q Running' 60
    
    kubectl expose pod net-test-3 --port=80 --name=net-test-service-2 -n net-test-ns &>/dev/null
    sleep 5
    assert_success "Cross-namespace service connectivity works" 'kubectl exec net-test-2 -- wget -qO- net-test-service-2.net-test-ns.svc.cluster.local 2>/dev/null | grep -q nginx'
    
    # Test 5: NodePort service access
    log_info "Testing NodePort service..."
    kubectl expose pod net-test-1 --port=80 --type=NodePort --name=net-test-nodeport &>/dev/null
    local nodeport=$(kubectl get service net-test-nodeport -o jsonpath='{.spec.ports[0].nodePort}')
    assert_success "NodePort service is created" '[ -n "$nodeport" ]'
    
    # Cleanup
    kubectl delete pod net-test-1 net-test-2 --ignore-not-found=true &>/dev/null
    kubectl delete pod net-test-3 -n net-test-ns --ignore-not-found=true &>/dev/null
    kubectl delete service net-test-service net-test-nodeport --ignore-not-found=true &>/dev/null
    kubectl delete service net-test-service-2 -n net-test-ns --ignore-not-found=true &>/dev/null
    kubectl delete namespace net-test-ns --ignore-not-found=true &>/dev/null
    
    # Print summary
    print_test_summary
}

# Handle script interruption
trap cleanup_test_resources EXIT

# Run main function
main "$@"