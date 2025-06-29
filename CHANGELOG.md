# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased] - 2024-06-29

### Added
- Comprehensive testing framework with multiple test suites
  - `tests/test_cluster.sh` - Core cluster functionality tests
  - `tests/test_networking.sh` - Network connectivity and pod communication tests
  - `tests/test_storage.sh` - Storage and volume functionality tests
  - `tests/test_services.sh` - Service discovery and load balancing tests
- Main validation script (`validate.sh`) for prerequisites and configuration checks
- Environment setup script (`setup.sh`) for automated tool installation
- `Makefile` for common development tasks
- GitHub Actions workflow for automated validation
- Comprehensive documentation updates with testing procedures

### Changed
- **BREAKING**: Updated Kubernetes version from mixed 1.25.5/1.26.1 to consistent 1.28.2 (LTS)
- Updated Docker repository from deprecated `xenial` to `focal` for Ubuntu 20.04 support
- Updated Kubernetes repository to use new GPG keys and package sources
- Standardized both main and CKS Vagrant configurations to use same Kubernetes version
- Enhanced README with detailed setup instructions, troubleshooting, and testing guide

### Fixed
- Removed hardcoded username `jpoley` from Ansible playbooks
- Fixed inconsistent Kubernetes component versions across master and worker nodes
- Updated deprecated repository URLs for Docker and Kubernetes packages
- Fixed typo in Docker daemon configuration file path (`ddaemon.json` → `daemon.json`)

### Security
- Updated to use official Kubernetes package repository with proper GPG verification
- Removed deprecated apt keys and repositories

## Previous Versions

### Features inherited from original repository:
- Multi-node Kubernetes cluster setup with Vagrant and Ansible
- VirtualBox provider support with configurable VM resources  
- Calico networking plugin for pod communication
- Alternative CKS (Certified Kubernetes Security) configuration
- Support for 1 master + 2 worker nodes architecture