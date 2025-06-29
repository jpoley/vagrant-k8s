#!/bin/bash
# Storage functionality tests

set -e

# Source helper functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

main() {
    log_info "Starting storage functionality tests"
    
    # Cleanup any existing test resources
    cleanup_test_resources
    
    # Test 1: EmptyDir volume
    log_info "Testing EmptyDir volumes..."
    cat <<EOF | kubectl apply -f - &>/dev/null
apiVersion: v1
kind: Pod
metadata:
  name: storage-test-emptydir
spec:
  containers:
  - name: container-1
    image: busybox
    command: ["/bin/sh", "-c", "echo 'Hello from container 1' > /shared/data.txt && sleep 3600"]
    volumeMounts:
    - name: shared-volume
      mountPath: /shared
  - name: container-2
    image: busybox
    command: ["/bin/sh", "-c", "sleep 10 && cat /shared/data.txt && sleep 3600"]
    volumeMounts:
    - name: shared-volume
      mountPath: /shared
  volumes:
  - name: shared-volume
    emptyDir: {}
EOF
    
    wait_for_condition "emptydir pod is running" 'kubectl get pod storage-test-emptydir -o jsonpath="{.status.phase}" | grep -q Running' 60
    sleep 15  # Give time for the file to be written and read
    assert_success "EmptyDir volume sharing works" 'kubectl logs storage-test-emptydir -c container-2 | grep -q "Hello from container 1"'
    
    # Test 2: HostPath volume (basic functionality)
    log_info "Testing HostPath volumes..."
    cat <<EOF | kubectl apply -f - &>/dev/null
apiVersion: v1
kind: Pod
metadata:
  name: storage-test-hostpath
spec:
  containers:
  - name: container
    image: busybox
    command: ["/bin/sh", "-c", "echo 'HostPath test' > /host-data/test.txt && cat /host-data/test.txt && sleep 3600"]
    volumeMounts:
    - name: host-volume
      mountPath: /host-data
  volumes:
  - name: host-volume
    hostPath:
      path: /tmp/k8s-hostpath-test
      type: DirectoryOrCreate
EOF
    
    wait_for_condition "hostpath pod is running" 'kubectl get pod storage-test-hostpath -o jsonpath="{.status.phase}" | grep -q Running' 60
    sleep 10
    assert_success "HostPath volume works" 'kubectl logs storage-test-hostpath | grep -q "HostPath test"'
    
    # Test 3: ConfigMap as volume
    log_info "Testing ConfigMap volumes..."
    kubectl create configmap storage-test-config --from-literal=config.txt="This is a config file" &>/dev/null
    
    cat <<EOF | kubectl apply -f - &>/dev/null
apiVersion: v1
kind: Pod
metadata:
  name: storage-test-configmap
spec:
  containers:
  - name: container
    image: busybox
    command: ["/bin/sh", "-c", "cat /config/config.txt && sleep 3600"]
    volumeMounts:
    - name: config-volume
      mountPath: /config
  volumes:
  - name: config-volume
    configMap:
      name: storage-test-config
EOF
    
    wait_for_condition "configmap pod is running" 'kubectl get pod storage-test-configmap -o jsonpath="{.status.phase}" | grep -q Running' 60
    sleep 10
    assert_success "ConfigMap volume works" 'kubectl logs storage-test-configmap | grep -q "This is a config file"'
    
    # Test 4: Secret as volume
    log_info "Testing Secret volumes..."
    kubectl create secret generic storage-test-secret --from-literal=secret.txt="This is a secret" &>/dev/null
    
    cat <<EOF | kubectl apply -f - &>/dev/null
apiVersion: v1
kind: Pod
metadata:
  name: storage-test-secret
spec:
  containers:
  - name: container
    image: busybox
    command: ["/bin/sh", "-c", "cat /secret/secret.txt && sleep 3600"]
    volumeMounts:
    - name: secret-volume
      mountPath: /secret
  volumes:
  - name: secret-volume
    secret:
      secretName: storage-test-secret
EOF
    
    wait_for_condition "secret pod is running" 'kubectl get pod storage-test-secret -o jsonpath="{.status.phase}" | grep -q Running' 60
    sleep 10
    assert_success "Secret volume works" 'kubectl logs storage-test-secret | grep -q "This is a secret"'
    
    # Test 5: Storage class availability (if any)
    log_info "Checking storage classes..."
    if kubectl get storageclass &>/dev/null; then
        assert_success "Storage classes are available" 'kubectl get storageclass --no-headers | wc -l | grep -v "^0$"'
    else
        log_warn "No storage classes found - this is normal for basic cluster setups"
    fi
    
    # Cleanup
    kubectl delete pod storage-test-emptydir storage-test-hostpath storage-test-configmap storage-test-secret --ignore-not-found=true &>/dev/null
    kubectl delete configmap storage-test-config --ignore-not-found=true &>/dev/null
    kubectl delete secret storage-test-secret --ignore-not-found=true &>/dev/null
    
    # Print summary
    print_test_summary
}

# Handle script interruption
trap cleanup_test_resources EXIT

# Run main function
main "$@"