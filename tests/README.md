# OCS Multi-Distribution Testing Framework

This testing framework validates the Open Cluster Scheduler (OCS) installation script across multiple Linux distributions using Docker containers.

## Supported Distributions

- Rocky Linux 9 (`rockylinux:9`)
- Ubuntu 22.04 LTS (`ubuntu:22.04`)
- Ubuntu 24.04 LTS (`ubuntu:24.04`)
- openSUSE Leap 15.5 (`opensuse/leap:15.5`)
- openSUSE Leap 15.6 (`opensuse/leap:15.6`)
- CentOS 7 (EOL) (`quay.io/centos/centos:7`)

## Test Scenarios

### Single-Node Tests
Each distribution is tested in standalone mode with both qmaster and execd on the same node.

### Cluster Tests  
Multi-node cluster with:
- **Master**: Rocky Linux 9.6 (qmaster + execd)
- **Execd nodes**: Ubuntu 22.04 and openSUSE Leap 15.6

## Quick Start

```bash
# Run all tests (single-node + cluster)
./tests/run_tests.sh all

# Run single-node tests only
./tests/run_tests.sh single

# Run cluster tests only  
./tests/run_tests.sh cluster

# Test specific distribution (builds only required image)
./tests/run_tests.sh rocky96
./tests/run_tests.sh ubuntu2204

# Build only specific images
./tests/run_tests.sh build ubuntu2204-single
./tests/run_tests.sh build rocky96-single opensuse156-single

# Test specific OCS version
./tests/run_tests.sh --version 9.0.7 all

# Clean up containers
./tests/run_tests.sh clean
```

## Test Commands

The framework validates OCS installation by running:

- `qhost` - Display cluster hosts
- `qstat -f` - Show queue status
- `qconf -sql` - List queues
- `qconf -sel` - List execution hosts
- `qconf -ss` - Show scheduler status
- `qsub -sync y -b y hostname` - Submit test job
- Process checks for `sge_qmaster` and `sge_execd`

## Test Reports

Test results are saved in `tests/reports/` with:
- Individual container reports
- Overall test summary
- Installation logs and debugging info

## Directory Structure

```
tests/
├── run_tests.sh                  # Main test runner
├── docker-compose.yml            # Legacy - combined services
├── docker-compose.single.yml     # Single-node test services
├── docker-compose.cluster.yml    # Multi-node cluster services
├── common/                       # Shared test utilities
│   ├── test_functions.sh         # Test framework functions
│   ├── wait_for_ocs.sh          # OCS readiness checker
│   ├── cluster_validation.sh     # Validation tests
│   └── install_and_test.sh      # Main installation script
├── rocky9.6/Dockerfile          # Rocky Linux container
├── ubuntu22.04/Dockerfile       # Ubuntu 22.04 container
├── ubuntu24.04/Dockerfile       # Ubuntu 24.04 container
├── opensuse-leap15.5/Dockerfile # openSUSE 15.5 container
├── opensuse-leap15.6/Dockerfile # openSUSE 15.6 container  
├── centos7/Dockerfile            # CentOS 7 container
└── reports/                      # Test output directory
```

## Requirements

- Docker and Docker Compose
- At least 4GB RAM for running multiple containers
- Network access for downloading OCS packages
- `timeout` command (Linux) or `gtimeout` (macOS with `brew install coreutils`)
  - On macOS: `brew install coreutils` (optional, fallback available)

## Environment Variables

- `OCS_VERSION` - OCS version to test (default: 9.0.6)
- `OCS_CLUSTER_SECRET` - Cluster secret for multi-node tests
- `TEST_TIMEOUT` - Test timeout in seconds (default: 1800)

## Troubleshooting

### macOS Setup
```bash
# Install GNU coreutils for timeout command (optional)
brew install coreutils

# The script will fallback gracefully if timeout is not available
```

### Container Build Issues
```bash
# Clean build with no cache
docker-compose -f docker-compose.single.yml build --no-cache

# Test specific distribution only
docker-compose -f docker-compose.single.yml up ubuntu2204-single
docker logs ocs-test-ubuntu2204-single

# Test cluster setup only
docker-compose -f docker-compose.cluster.yml up rocky96-master ubuntu2204-execd

# Image availability issues
docker pull rockylinux:9
docker pull ubuntu:22.04
docker pull ubuntu:24.04
docker pull opensuse/leap:15.5
docker pull opensuse/leap:15.6
docker pull quay.io/centos/centos:7
```

### Network Issues
```bash
# Check container connectivity
docker exec ocs-test-rocky96-master ping ubuntu2204-execd
```

### OCS Installation Debug
```bash
# Access container shell
docker exec -it ocs-test-rocky96-master /bin/bash

# Check OCS status
source /opt/ocs/default/common/settings.sh
qhost
qstat -f
```

## CI/CD Integration

The framework can be integrated into CI/CD pipelines:

```yaml
# Example GitHub Actions
- name: Test OCS Installation
  run: |
    cd tests
    ./run_tests.sh all
    
- name: Upload Test Reports
  uses: actions/upload-artifact@v3
  with:
    name: ocs-test-reports
    path: tests/reports/
```