#!/bin/bash
# Comprehensive validation script for the vagrant-k8s setup

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="$SCRIPT_DIR/tests"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_header() {
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${BLUE} $1${NC}"
    echo -e "${BLUE}=====================================${NC}"
}

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --setup-only     Only run setup validation, skip cluster tests"
    echo "  --cluster-only   Only run cluster tests, skip setup validation"
    echo "  --skip-vagrant   Skip Vagrant-specific validations"
    echo "  -h, --help       Show this help message"
    echo ""
    echo "This script validates the vagrant-k8s setup by:"
    echo "1. Checking prerequisites (Vagrant, VirtualBox, Ansible)"
    echo "2. Validating Vagrant and Ansible configurations"
    echo "3. Running comprehensive cluster functionality tests"
    exit 1
}

check_prerequisites() {
    log_header "Checking Prerequisites"
    
    local errors=0
    local skip_vagrant_checks=${1:-false}
    
    # Check Vagrant (skip if requested)
    if [[ "$skip_vagrant_checks" != true ]]; then
        if command -v vagrant &> /dev/null; then
            local vagrant_version=$(vagrant --version)
            log_info "✓ Vagrant found: $vagrant_version"
        else
            log_error "✗ Vagrant not found. Please install Vagrant."
            ((errors++))
        fi
        
        # Check VirtualBox (skip if requested)
        if command -v vboxmanage &> /dev/null; then
            local vbox_version=$(vboxmanage --version)
            log_info "✓ VirtualBox found: $vbox_version"
        else
            log_error "✗ VirtualBox not found. Please install VirtualBox."
            ((errors++))
        fi
    else
        log_info "⚠ Skipping Vagrant and VirtualBox checks (--skip-vagrant flag used)"
    fi
    
    # Check Ansible
    if command -v ansible &> /dev/null; then
        local ansible_version=$(ansible --version | head -n1)
        log_info "✓ Ansible found: $ansible_version"
    else
        log_error "✗ Ansible not found. Please install Ansible."
        ((errors++))
    fi
    
    # Check ansible-playbook
    if command -v ansible-playbook &> /dev/null; then
        log_info "✓ ansible-playbook found"
    else
        log_error "✗ ansible-playbook not found. Please install Ansible."
        ((errors++))
    fi
    
    return $errors
}

validate_configurations() {
    log_header "Validating Configurations"
    
    local errors=0
    
    # Check Vagrantfile
    if [ -f "$SCRIPT_DIR/Vagrantfile" ]; then
        log_info "✓ Main Vagrantfile found"
        
        # Basic syntax check
        if vagrant validate &>/dev/null; then
            log_info "✓ Vagrantfile syntax is valid"
        else
            log_error "✗ Vagrantfile has syntax errors"
            ((errors++))
        fi
        
        # Check for provider flexibility
        if grep -q "config.vm.provider" "$SCRIPT_DIR/Vagrantfile"; then
            log_info "✓ VM provider configuration found"
        else
            log_warn "⚠ VM provider configuration not explicitly set"
        fi
        
    else
        log_error "✗ Main Vagrantfile not found"
        ((errors++))
    fi
    
    # Check Ansible playbooks
    if [ -f "$SCRIPT_DIR/kubernetes-setup/master-playbook.yml" ]; then
        log_info "✓ Master playbook found"
        
        # Basic syntax check
        if ansible-playbook --syntax-check "$SCRIPT_DIR/kubernetes-setup/master-playbook.yml" &>/dev/null; then
            log_info "✓ Master playbook syntax is valid"
        else
            log_error "✗ Master playbook has syntax errors"
            ((errors++))
        fi
    else
        log_error "✗ Master playbook not found"
        ((errors++))
    fi
    
    if [ -f "$SCRIPT_DIR/kubernetes-setup/node-playbook.yml" ]; then
        log_info "✓ Node playbook found"
        
        # Basic syntax check
        if ansible-playbook --syntax-check "$SCRIPT_DIR/kubernetes-setup/node-playbook.yml" &>/dev/null; then
            log_info "✓ Node playbook syntax is valid"
        else
            log_error "✗ Node playbook has syntax errors"
            ((errors++))
        fi
    else
        log_error "✗ Node playbook not found"
        ((errors++))
    fi
    
    # Check for consistency in Kubernetes versions
    local k8s_versions=($(grep -r "kubernetes-version\|kubeadm.*version" "$SCRIPT_DIR/kubernetes-setup/" 2>/dev/null | grep -oE "[0-9]+\.[0-9]+\.[0-9]+" | sort -u))
    if [ ${#k8s_versions[@]} -eq 1 ]; then
        log_info "✓ Consistent Kubernetes version: ${k8s_versions[0]}"
    elif [ ${#k8s_versions[@]} -gt 1 ]; then
        log_warn "⚠ Multiple Kubernetes versions found: ${k8s_versions[*]}"
    fi
    
    # Check alternative CKS setup
    if [ -f "$SCRIPT_DIR/CKS/hands-on/vagrant/Vagrantfile" ]; then
        log_info "✓ Alternative CKS Vagrantfile found"
        
        cd "$SCRIPT_DIR/CKS/hands-on/vagrant"
        if vagrant validate &>/dev/null; then
            log_info "✓ CKS Vagrantfile syntax is valid"
        else
            log_error "✗ CKS Vagrantfile has syntax errors"
            ((errors++))
        fi
        cd "$SCRIPT_DIR"
    fi
    
    return $errors
}

run_cluster_tests() {
    log_header "Running Cluster Tests"
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found. Please ensure the cluster is running and kubectl is configured."
        return 1
    fi
    
    # Check if cluster is accessible
    if ! kubectl cluster-info &>/dev/null; then
        log_error "Cannot connect to Kubernetes cluster. Please ensure the cluster is running."
        return 1
    fi
    
    local test_errors=0
    
    # Run main cluster tests
    if [ -x "$TEST_DIR/test_cluster.sh" ]; then
        log_info "Running main cluster tests..."
        if "$TEST_DIR/test_cluster.sh"; then
            log_info "✓ Main cluster tests passed"
        else
            log_error "✗ Main cluster tests failed"
            ((test_errors++))
        fi
    else
        log_warn "⚠ Main cluster test script not found or not executable"
    fi
    
    # Run networking tests
    if [ -x "$TEST_DIR/test_networking.sh" ]; then
        log_info "Running networking tests..."
        if "$TEST_DIR/test_networking.sh"; then
            log_info "✓ Networking tests passed"
        else
            log_error "✗ Networking tests failed"
            ((test_errors++))
        fi
    else
        log_warn "⚠ Networking test script not found or not executable"
    fi
    
    # Run storage tests
    if [ -x "$TEST_DIR/test_storage.sh" ]; then
        log_info "Running storage tests..."
        if "$TEST_DIR/test_storage.sh"; then
            log_info "✓ Storage tests passed"
        else
            log_error "✗ Storage tests failed"
            ((test_errors++))
        fi
    else
        log_warn "⚠ Storage test script not found or not executable"
    fi
    
    # Run service tests
    if [ -x "$TEST_DIR/test_services.sh" ]; then
        log_info "Running service tests..."
        if "$TEST_DIR/test_services.sh"; then
            log_info "✓ Service tests passed"
        else
            log_error "✗ Service tests failed"
            ((test_errors++))
        fi
    else
        log_warn "⚠ Service test script not found or not executable"
    fi
    
    return $test_errors
}

main() {
    local setup_only=false
    local cluster_only=false
    local skip_vagrant=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --setup-only)
                setup_only=true
                shift
                ;;
            --cluster-only)
                cluster_only=true
                shift
                ;;
            --skip-vagrant)
                skip_vagrant=true
                shift
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
    
    log_header "Vagrant-K8s Validation Script"
    
    local total_errors=0
    
    if [ "$cluster_only" != true ]; then
        # Check prerequisites
        if ! check_prerequisites "$skip_vagrant"; then
            ((total_errors++))
        fi
        
        # Skip Vagrant-specific checks if requested
        if [ "$skip_vagrant" != true ]; then
            # Validate configurations
            if ! validate_configurations; then
                ((total_errors++))
            fi
        fi
    fi
    
    if [ "$setup_only" != true ]; then
        # Run cluster tests
        if ! run_cluster_tests; then
            ((total_errors++))
        fi
    fi
    
    # Final summary
    log_header "Validation Summary"
    if [ $total_errors -eq 0 ]; then
        log_info "🎉 All validations passed successfully!"
        echo ""
        echo "Your vagrant-k8s setup is ready to use. You can now:"
        echo "1. Run 'vagrant up' to start the cluster"
        echo "2. Use 'vagrant ssh k8s-master' to access the master node"
        echo "3. Run the individual test scripts to validate specific functionality"
        return 0
    else
        log_error "❌ Validation completed with $total_errors error(s)"
        echo ""
        echo "Please address the errors before proceeding with the cluster setup."
        return 1
    fi
}

# Run main function
main "$@"