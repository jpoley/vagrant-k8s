#!/bin/bash
# Test script to deploy nginx and verify web server connectivity
# This validates end-to-end cluster functionality

# Source the helpers
SCRIPT_DIR="$(dirname "$0")"
. "${SCRIPT_DIR}/helpers.sh"

echo "=================================================="
echo "Nginx Deployment and Connectivity Test"
echo "=================================================="
echo ""

# Test 1: Deploy nginx
echo "Test 1: Deploying nginx application..."
kubectl create deployment nginx-test --image=nginx:latest --replicas=2 2>&1
assert_success $? "Deploy nginx deployment"

# Wait for deployment to be ready
echo "Waiting for nginx deployment to be ready..."
wait_for_condition "kubectl get deployment nginx-test -o jsonpath='{.status.readyReplicas}' 2>/dev/null | grep -q '^2$'" 120 "nginx deployment ready"
assert_success $? "Nginx deployment ready with 2 replicas"

# Test 2: Create service
echo ""
echo "Test 2: Creating nginx service..."
kubectl expose deployment nginx-test --port=80 --target-port=80 --type=NodePort --name=nginx-test-service 2>&1
assert_success $? "Create nginx service"

# Wait for service to be ready
sleep 5

# Get service details
SERVICE_IP=$(kubectl get service nginx-test-service -o jsonpath='{.spec.clusterIP}')
NODE_PORT=$(kubectl get service nginx-test-service -o jsonpath='{.spec.ports[0].nodePort}')
echo "Service ClusterIP: ${SERVICE_IP}"
echo "Service NodePort: ${NODE_PORT}"

# Test 3: Verify pods are running
echo ""
echo "Test 3: Verifying nginx pods are running..."
RUNNING_PODS=$(kubectl get pods -l app=nginx-test --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
assert_equals "${RUNNING_PODS}" "2" "Two nginx pods running"

# Test 4: Test connectivity from within the cluster using a test pod
echo ""
echo "Test 4: Testing web server connectivity from within cluster..."

# Create a test pod with curl
cat <<EOF | kubectl apply -f - 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: curl-test-pod
spec:
  containers:
  - name: curl
    image: curlimages/curl:latest
    command: ['sleep', '3600']
  restartPolicy: Never
EOF

# Wait for test pod to be ready
echo "Waiting for curl test pod to be ready..."
wait_for_condition "kubectl get pod curl-test-pod -o jsonpath='{.status.phase}' 2>/dev/null | grep -q 'Running'" 60 "curl test pod ready"

# Test HTTP connectivity to ClusterIP
echo "Testing HTTP request to nginx service (ClusterIP)..."
HTTP_RESPONSE=$(kubectl exec curl-test-pod -- curl -s -o /dev/null -w "%{http_code}" http://${SERVICE_IP}:80 2>/dev/null)
assert_equals "${HTTP_RESPONSE}" "200" "HTTP request to nginx service returns 200"

# Get actual response content
echo "Fetching nginx response content..."
RESPONSE_CONTENT=$(kubectl exec curl-test-pod -- curl -s http://${SERVICE_IP}:80 2>/dev/null | head -n 1)
echo "Response: ${RESPONSE_CONTENT}"
if echo "${RESPONSE_CONTENT}" | grep -q "nginx\|Welcome\|DOCTYPE"; then
    assert_success 0 "Nginx welcome page received"
else
    assert_success 1 "Nginx welcome page received"
fi

# Test 5: Test connectivity to individual pods
echo ""
echo "Test 5: Testing direct pod connectivity..."
POD_NAME=$(kubectl get pods -l app=nginx-test -o jsonpath='{.items[0].metadata.name}')
POD_IP=$(kubectl get pod ${POD_NAME} -o jsonpath='{.status.podIP}')
echo "Testing pod ${POD_NAME} at IP ${POD_IP}..."

POD_RESPONSE=$(kubectl exec curl-test-pod -- curl -s -o /dev/null -w "%{http_code}" http://${POD_IP}:80 2>/dev/null)
assert_equals "${POD_RESPONSE}" "200" "HTTP request to nginx pod returns 200"

# Test 6: Verify service load balancing by checking endpoints
echo ""
echo "Test 6: Verifying service endpoints..."
ENDPOINT_COUNT=$(kubectl get endpoints nginx-test-service -o jsonpath='{.subsets[0].addresses}' | grep -o 'ip' | wc -l)
assert_equals "${ENDPOINT_COUNT}" "2" "Service has 2 endpoints"

# Test 7: Test service DNS resolution
echo ""
echo "Test 7: Testing service DNS resolution..."
DNS_RESPONSE=$(kubectl exec curl-test-pod -- nslookup nginx-test-service.default.svc.cluster.local 2>&1)
if echo "${DNS_RESPONSE}" | grep -q "${SERVICE_IP}"; then
    assert_success 0 "Service DNS resolves correctly"
else
    assert_success 1 "Service DNS resolves correctly"
    echo "DNS Response: ${DNS_RESPONSE}"
fi

# Test 8: Test using service DNS name
echo ""
echo "Test 8: Testing HTTP request using service DNS name..."
DNS_HTTP_RESPONSE=$(kubectl exec curl-test-pod -- curl -s -o /dev/null -w "%{http_code}" http://nginx-test-service.default.svc.cluster.local:80 2>/dev/null)
assert_equals "${DNS_HTTP_RESPONSE}" "200" "HTTP request via DNS name returns 200"

# Test 9: Scale deployment and verify
echo ""
echo "Test 9: Testing deployment scaling..."
kubectl scale deployment nginx-test --replicas=3 2>&1
wait_for_condition "kubectl get deployment nginx-test -o jsonpath='{.status.readyReplicas}' 2>/dev/null | grep -q '^3$'" 60 "deployment scaled to 3 replicas"
assert_success $? "Deployment scaled to 3 replicas"

SCALED_PODS=$(kubectl get pods -l app=nginx-test --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
assert_equals "${SCALED_PODS}" "3" "Three nginx pods running after scaling"

# Cleanup
echo ""
echo "Cleaning up test resources..."
kubectl delete pod curl-test-pod --ignore-not-found=true 2>&1 > /dev/null
kubectl delete service nginx-test-service --ignore-not-found=true 2>&1 > /dev/null
kubectl delete deployment nginx-test --ignore-not-found=true 2>&1 > /dev/null

echo ""
echo "Waiting for cleanup to complete..."
sleep 10

# Print summary
echo ""
print_test_summary
