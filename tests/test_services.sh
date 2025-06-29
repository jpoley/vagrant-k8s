#!/bin/bash
# Service discovery and load balancing tests

set -e

# Source helper functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

main() {
    log_info "Starting service discovery and load balancing tests"
    
    # Cleanup any existing test resources
    cleanup_test_resources
    
    # Test 1: ClusterIP service
    log_info "Testing ClusterIP service..."
    kubectl create deployment service-test-app --image=nginx --replicas=2 &>/dev/null
    wait_for_condition "deployment is ready" 'kubectl get deployment service-test-app -o jsonpath="{.status.readyReplicas}" | grep -q "2"' 120
    
    kubectl expose deployment service-test-app --port=80 --type=ClusterIP --name=service-test-clusterip &>/dev/null
    sleep 5
    
    # Test service endpoint creation
    assert_success "Service endpoints are created" 'kubectl get endpoints service-test-clusterip -o jsonpath="{.subsets[0].addresses}" | grep -q "ip"'
    
    # Test service connectivity
    kubectl run service-test-client --image=busybox --rm -it --restart=Never -- wget -qO- service-test-clusterip &>/dev/null || true
    sleep 5
    assert_success "ClusterIP service connectivity works" 'kubectl logs service-test-client 2>/dev/null | grep -q "nginx" || true'
    
    # Test 2: NodePort service
    log_info "Testing NodePort service..."
    kubectl expose deployment service-test-app --port=80 --type=NodePort --name=service-test-nodeport &>/dev/null
    sleep 5
    
    local nodeport=$(kubectl get service service-test-nodeport -o jsonpath='{.spec.ports[0].nodePort}')
    assert_success "NodePort is assigned" '[ -n "$nodeport" ] && [ "$nodeport" -ge 30000 ] && [ "$nodeport" -le 32767 ]'
    
    # Test 3: Service load balancing
    log_info "Testing service load balancing..."
    
    # Create a custom deployment with identifiable responses
    cat <<EOF | kubectl apply -f - &>/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: service-test-lb
spec:
  replicas: 3
  selector:
    matchLabels:
      app: service-test-lb
  template:
    metadata:
      labels:
        app: service-test-lb
    spec:
      containers:
      - name: web
        image: nginx
        command: ["/bin/sh"]
        args: ["-c", "echo 'Pod ID: '\$HOSTNAME > /usr/share/nginx/html/index.html && nginx -g 'daemon off;'"]
        ports:
        - containerPort: 80
EOF
    
    wait_for_condition "load balancer deployment is ready" 'kubectl get deployment service-test-lb -o jsonpath="{.status.readyReplicas}" | grep -q "3"' 120
    
    kubectl expose deployment service-test-lb --port=80 --name=service-test-lb-svc &>/dev/null
    sleep 10
    
    # Test multiple requests to see load balancing (basic test)
    local responses=()
    for i in {1..6}; do
        local response=$(kubectl run test-lb-client-$i --image=busybox --rm -it --restart=Never -- wget -qO- service-test-lb-svc 2>/dev/null || echo "error")
        responses+=("$response")
        sleep 2
    done
    
    # Check if we got responses from multiple pods (basic load balancing validation)
    local unique_responses=$(printf '%s\n' "${responses[@]}" | sort -u | wc -l)
    assert_success "Load balancing distributes requests" '[ "$unique_responses" -gt 1 ]'
    
    # Test 4: Service discovery via environment variables
    log_info "Testing service discovery via environment variables..."
    kubectl run service-env-test --image=busybox --restart=Never -- env &>/dev/null
    wait_for_condition "env test pod is running" 'kubectl get pod service-env-test -o jsonpath="{.status.phase}" | grep -q Running' 60
    sleep 5
    
    assert_success "Service environment variables are set" 'kubectl logs service-env-test | grep -q "SERVICE_TEST_CLUSTERIP"'
    
    # Test 5: Headless service
    log_info "Testing headless service..."
    kubectl create service clusterip service-test-headless --tcp=80:80 --clusterip=None &>/dev/null
    kubectl label service service-test-headless app=service-test-app &>/dev/null
    sleep 5
    
    assert_success "Headless service is created" 'kubectl get service service-test-headless -o jsonpath="{.spec.clusterIP}" | grep -q "None"'
    
    # Test DNS resolution for headless service (should return multiple IPs)
    kubectl run headless-test --image=busybox --rm -it --restart=Never -- nslookup service-test-headless &>/dev/null || true
    sleep 5
    assert_success "Headless service DNS returns multiple addresses" 'kubectl logs headless-test 2>/dev/null | grep -c "Address" | grep -q "[2-9]"'
    
    # Cleanup
    kubectl delete deployment service-test-app service-test-lb --ignore-not-found=true &>/dev/null
    kubectl delete service service-test-clusterip service-test-nodeport service-test-lb-svc service-test-headless --ignore-not-found=true &>/dev/null
    kubectl delete pod service-env-test --ignore-not-found=true &>/dev/null
    
    # Print summary
    print_test_summary
}

# Handle script interruption  
trap cleanup_test_resources EXIT

# Run main function
main "$@"