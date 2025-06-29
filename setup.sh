#!/bin/bash
# Environment setup script for vagrant-k8s

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
    echo "  --auto         Automatically install prerequisites without prompting"
    echo "  --provider     VM provider to use (virtualbox, vmware, libvirt)"
    echo "  -h, --help     Show this help message"
    echo ""
    echo "This script helps set up the environment for vagrant-k8s by:"
    echo "1. Detecting your platform (Linux, macOS, Windows)"
    echo "2. Installing required tools (Vagrant, VirtualBox, Ansible)"
    echo "3. Configuring the appropriate VM provider"
    exit 1
}

detect_platform() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
        echo "windows"
    else
        echo "unknown"
    fi
}

install_vagrant_linux() {
    log_info "Installing Vagrant on Linux..."
    
    if command -v apt-get &> /dev/null; then
        # Debian/Ubuntu
        wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
        sudo apt-get update && sudo apt-get install -y vagrant
    elif command -v yum &> /dev/null; then
        # RHEL/CentOS/Fedora
        sudo yum install -y yum-utils
        sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
        sudo yum install -y vagrant
    elif command -v pacman &> /dev/null; then
        # Arch Linux
        sudo pacman -S vagrant
    else
        log_error "Unsupported Linux distribution. Please install Vagrant manually."
        return 1
    fi
}

install_virtualbox_linux() {
    log_info "Installing VirtualBox on Linux..."
    
    if command -v apt-get &> /dev/null; then
        # Debian/Ubuntu
        sudo apt-get update
        sudo apt-get install -y virtualbox virtualbox-ext-pack
    elif command -v yum &> /dev/null; then
        # RHEL/CentOS/Fedora
        sudo yum install -y VirtualBox
    elif command -v pacman &> /dev/null; then
        # Arch Linux
        sudo pacman -S virtualbox virtualbox-host-modules-arch
    else
        log_error "Unsupported Linux distribution. Please install VirtualBox manually."
        return 1
    fi
}

install_ansible_linux() {
    log_info "Installing Ansible on Linux..."
    
    if command -v apt-get &> /dev/null; then
        # Debian/Ubuntu
        sudo apt-get update
        sudo apt-get install -y ansible
    elif command -v yum &> /dev/null; then
        # RHEL/CentOS/Fedora
        sudo yum install -y ansible
    elif command -v pacman &> /dev/null; then
        # Arch Linux
        sudo pacman -S ansible
    else
        # Fallback to pip
        if command -v pip3 &> /dev/null; then
            pip3 install --user ansible
        else
            log_error "Cannot install Ansible. Please install it manually."
            return 1
        fi
    fi
}

install_macos() {
    log_info "Installing tools on macOS..."
    
    # Check if Homebrew is installed
    if ! command -v brew &> /dev/null; then
        log_info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    
    # Install tools via Homebrew
    log_info "Installing Vagrant, VirtualBox, and Ansible..."
    brew install --cask vagrant virtualbox
    brew install ansible
}

install_windows() {
    log_info "For Windows, please install the following tools manually:"
    echo "1. Vagrant: https://www.vagrantup.com/downloads"
    echo "2. VirtualBox: https://www.virtualbox.org/wiki/Downloads"
    echo "3. Ansible: Use WSL2 with Ubuntu and install ansible via apt"
    log_warn "Consider using WSL2 (Windows Subsystem for Linux) for the best experience."
}

check_provider_support() {
    local provider=$1
    
    case $provider in
        virtualbox)
            if command -v vboxmanage &> /dev/null; then
                log_info "✓ VirtualBox provider is available"
                return 0
            else
                log_error "VirtualBox is not installed"
                return 1
            fi
            ;;
        vmware)
            if command -v vmrun &> /dev/null; then
                log_info "✓ VMware provider is available"
                return 0
            else
                log_error "VMware is not installed"
                return 1
            fi
            ;;
        libvirt)
            if command -v virsh &> /dev/null; then
                log_info "✓ Libvirt provider is available"
                return 0
            else
                log_error "Libvirt is not installed"
                return 1
            fi
            ;;
        *)
            log_error "Unsupported provider: $provider"
            return 1
            ;;
    esac
}

configure_provider() {
    local provider=$1
    
    case $provider in
        vmware)
            log_info "Installing VMware provider plugin..."
            vagrant plugin install vagrant-vmware-desktop
            ;;
        libvirt)
            log_info "Installing Libvirt provider plugin..."
            vagrant plugin install vagrant-libvirt
            ;;
        virtualbox)
            log_info "VirtualBox provider is built-in to Vagrant"
            ;;
    esac
}

main() {
    local auto_install=false
    local provider="virtualbox"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --auto)
                auto_install=true
                shift
                ;;
            --provider)
                provider="$2"
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
    
    log_header "Vagrant-K8s Environment Setup"
    
    local platform=$(detect_platform)
    log_info "Detected platform: $platform"
    log_info "Target provider: $provider"
    
    # Check if tools are already installed
    local install_vagrant=false
    local install_virtualbox=false
    local install_ansible=false
    
    if ! command -v vagrant &> /dev/null; then
        install_vagrant=true
    else
        log_info "✓ Vagrant is already installed: $(vagrant --version)"
    fi
    
    if ! command -v ansible &> /dev/null; then
        install_ansible=true
    else
        log_info "✓ Ansible is already installed: $(ansible --version | head -n1)"
    fi
    
    if [ "$provider" = "virtualbox" ] && ! command -v vboxmanage &> /dev/null; then
        install_virtualbox=true
    elif [ "$provider" = "virtualbox" ]; then
        log_info "✓ VirtualBox is already installed: $(vboxmanage --version)"
    fi
    
    # Install missing tools
    if [ "$install_vagrant" = true ] || [ "$install_virtualbox" = true ] || [ "$install_ansible" = true ]; then
        if [ "$auto_install" = false ]; then
            echo ""
            read -p "Install missing tools? (y/N): " -n 1 -r
            echo ""
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Installation cancelled. Please install the required tools manually."
                exit 0
            fi
        fi
        
        case $platform in
            linux)
                [ "$install_vagrant" = true ] && install_vagrant_linux
                [ "$install_virtualbox" = true ] && install_virtualbox_linux
                [ "$install_ansible" = true ] && install_ansible_linux
                ;;
            macos)
                install_macos
                ;;
            windows)
                install_windows
                exit 0
                ;;
            *)
                log_error "Unsupported platform: $platform"
                exit 1
                ;;
        esac
    fi
    
    # Configure provider
    if check_provider_support "$provider"; then
        configure_provider "$provider"
    else
        log_error "Provider $provider is not available"
        exit 1
    fi
    
    # Final validation
    log_header "Final Validation"
    if ./validate.sh --setup-only; then
        log_info "🎉 Environment setup completed successfully!"
        echo ""
        echo "You can now run:"
        echo "  make up      # Start the cluster"
        echo "  make test    # Run all tests"
        echo "  make help    # See all available commands"
    else
        log_error "Environment setup completed with errors. Please check the output above."
        exit 1
    fi
}

# Run main function
main "$@"