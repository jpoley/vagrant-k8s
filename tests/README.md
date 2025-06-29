This directory contains test scripts for validating the Kubernetes cluster setup.

## Test Structure

- `test_cluster.sh` - Main test script that validates cluster functionality
- `test_networking.sh` - Tests for network connectivity and pod communication
- `test_storage.sh` - Tests for persistent volume functionality
- `test_services.sh` - Tests for service discovery and load balancing
- `helpers/` - Common helper functions for testing

## Usage

Run all tests:
```bash
./test_cluster.sh
```

Run specific test categories:
```bash
./test_networking.sh
./test_storage.sh
./test_services.sh
```