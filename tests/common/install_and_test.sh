#!/bin/bash
#
#___INFO__MARK_BEGIN_NEW__
###########################################################################
#
#  Copyright 2025 HPC-Gridware GmbH
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#
###########################################################################
#___INFO__MARK_END_NEW__
#
# Main installation and testing script for OCS
#

set -e

# Source test functions
# shellcheck source=test_functions.sh
. "$(dirname "$0")/test_functions.sh"

# Configuration
INSTALL_MODE=${OCS_INSTALL_MODE:-single}
OCS_VERSION=${OCS_VERSION:-9.0.6}
TEST_TYPE=${TEST_TYPE:-single}
HOSTNAME=$(hostname)

log_info "Starting OCS installation and testing"
log_info "Hostname: $HOSTNAME"
log_info "Install Mode: $INSTALL_MODE"
log_info "OCS Version: $OCS_VERSION"
log_info "Test Type: $TEST_TYPE"

# Create reports directory
mkdir -p /opt/reports

# Step 1: Install OCS
log_info "Step 1: Installing OCS"
cd /home/testuser

# Copy ocs.sh script to home directory
cp /opt/ocs.sh ./ocs.sh
chmod +x ./ocs.sh

# Run installation
case "$INSTALL_MODE" in
    "single")
        log_info "Running single-node installation"
        if ./ocs.sh; then
            log_success "OCS installation completed"
        else
            log_error "OCS installation failed"
            exit 1
        fi
        ;;
        
    "full")
        log_info "Running full cluster master installation"
        if ./ocs.sh; then
            log_success "OCS master installation completed"
        else
            log_error "OCS master installation failed"
            exit 1
        fi
        ;;
        
    "execd")
        log_info "Running execd-only installation"
        # For execd mode, we need to wait for shared filesystem and master
        if ./ocs.sh; then
            log_success "OCS execd installation completed"
        else
            log_error "OCS execd installation failed"
            exit 1
        fi
        ;;
        
    *)
        log_error "Unknown install mode: $INSTALL_MODE"
        exit 1
        ;;
esac

# Step 2: Wait for OCS to be ready
log_info "Step 2: Waiting for OCS services to start"
if /opt/test-scripts/wait_for_ocs.sh 1200; then  # 20 minute timeout
    log_success "OCS services are ready"
else
    log_error "OCS services failed to start properly"
    exit 1
fi

# Step 3: Run validation tests
log_info "Step 3: Running validation tests"
if /opt/test-scripts/cluster_validation.sh; then
    log_success "All validation tests passed"
else
    log_error "Some validation tests failed"
    exit 1
fi

log_success "OCS installation and testing completed successfully for $HOSTNAME"