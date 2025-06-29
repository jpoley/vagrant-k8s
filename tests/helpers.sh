#!/bin/bash
# Helper functions for Kubernetes cluster testing

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Log functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Test result tracking
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_TESTS=()

# Test assertion functions
assert_success() {
    local description=$1
    local command=$2
    
    log_info "Testing: $description"
    if eval "$command" &>/dev/null; then
        log_info "✓ PASS: $description"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "✗ FAIL: $description"
        FAILED_TESTS+=("$description")
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_equals() {
    local description=$1
    local expected=$2
    local actual=$3
    
    log_info "Testing: $description"
    if [ "$expected" = "$actual" ]; then
        log_info "✓ PASS: $description"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "✗ FAIL: $description (expected: $expected, actual: $actual)"
        FAILED_TESTS+=("$description")
        ((TESTS_FAILED++))
        return 1
    fi
}

wait_for_condition() {
    local description=$1
    local condition=$2
    local timeout=${3:-300}  # Default 5 minutes
    local interval=${4:-10}  # Default 10 seconds
    
    log_info "Waiting for: $description (timeout: ${timeout}s)"
    local elapsed=0
    
    while [ $elapsed -lt $timeout ]; do
        if eval "$condition" &>/dev/null; then
            log_info "✓ Condition met: $description"
            return 0
        fi
        sleep $interval
        elapsed=$((elapsed + interval))
        echo -n "."
    done
    
    echo ""
    log_error "✗ Timeout waiting for: $description"
    return 1
}

# Print test summary
print_test_summary() {
    echo ""
    echo "=================================="
    echo "         TEST SUMMARY"
    echo "=================================="
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $TESTS_FAILED"
    echo "Total:  $((TESTS_PASSED + TESTS_FAILED))"
    
    if [ $TESTS_FAILED -gt 0 ]; then
        echo ""
        echo "Failed tests:"
        for test in "${FAILED_TESTS[@]}"; do
            echo "  - $test"
        done
        echo ""
        return 1
    else
        echo ""
        log_info "All tests passed!"
        return 0
    fi
}

# Kubernetes utility functions
get_node_count() {
    kubectl get nodes --no-headers 2>/dev/null | wc -l
}

get_ready_node_count() {
    kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready "
}

get_pod_count() {
    kubectl get pods --all-namespaces --no-headers 2>/dev/null | wc -l
}

get_running_pod_count() {
    kubectl get pods --all-namespaces --no-headers 2>/dev/null | grep -c " Running "
}

is_cluster_ready() {
    local expected_nodes=${1:-3}  # Default to 3 nodes (1 master + 2 workers)
    local ready_nodes=$(get_ready_node_count)
    [ "$ready_nodes" -eq "$expected_nodes" ]
}

cleanup_test_resources() {
    log_info "Cleaning up test resources..."
    kubectl delete namespace test-namespace --ignore-not-found=true &>/dev/null
    kubectl delete pod test-pod --ignore-not-found=true &>/dev/null
    kubectl delete service test-service --ignore-not-found=true &>/dev/null
    kubectl delete deployment test-deployment --ignore-not-found=true &>/dev/null
}