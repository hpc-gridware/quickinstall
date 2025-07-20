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
# Wait for OCS installation and services to be ready
#

# Source test functions
# shellcheck source=test_functions.sh
. "$(dirname "$0")/test_functions.sh"

# Default timeout (20 minutes)
TIMEOUT=${1:-1200}
INSTALL_MODE=${OCS_INSTALL_MODE:-single}

log_info "Waiting for OCS installation to complete (mode: $INSTALL_MODE, timeout: ${TIMEOUT}s)"

# Function to check if OCS installation is complete
check_ocs_ready() {
    case "$INSTALL_MODE" in
        "single"|"full")
            # Check if qmaster is running
            if ! check_ocs_installed; then
                return 1
            fi
            
            # Source environment and check qmaster
            if ! source_ocs_env; then
                return 1
            fi
            
            # Check if qmaster process is running
            if ! pgrep -f sge_qmaster >/dev/null 2>&1; then
                return 1
            fi
            
            # Check if execd is running
            if ! pgrep -f sge_execd >/dev/null 2>&1; then
                return 1
            fi
            
            # Try basic qhost command
            if ! qhost >/dev/null 2>&1; then
                return 1
            fi
            
            log_info "OCS master and execd are ready"
            return 0
            ;;
            
        "execd")
            # For execd mode, wait for installation and daemon
            if ! check_ocs_installed; then
                return 1
            fi
            
            # Check if execd process is running
            if ! pgrep -f sge_execd >/dev/null 2>&1; then
                return 1
            fi
            
            log_info "OCS execd is ready"
            return 0
            ;;
            
        *)
            log_error "Unknown install mode: $INSTALL_MODE"
            return 1
            ;;
    esac
}

# Wait for OCS to be ready
if wait_for_command "check_ocs_ready" "$TIMEOUT" 15; then
    log_success "OCS is ready and operational"
    
    # Additional verification
    if source_ocs_env; then
        log_info "OCS Environment variables:"
        env | grep SGE || true
        
        if [ "$INSTALL_MODE" != "execd" ]; then
            log_info "Current cluster status:"
            qhost 2>/dev/null || log_warning "qhost command failed"
            qstat -f 2>/dev/null || log_warning "qstat command failed"
        fi
    fi
    
    exit 0
else
    log_error "OCS installation/startup failed or timed out"
    
    # Debug information
    log_info "Debug information:"
    echo "Processes:"
    ps aux | grep -E "(sge_|ocs)" || true
    echo ""
    echo "OCS directory contents:"
    ls -la /opt/ocs/ 2>/dev/null || echo "No /opt/ocs directory"
    echo ""
    echo "Installation logs:"
    find /tmp -name "*ocs*" -type f 2>/dev/null | head -5 | xargs ls -la || true
    
    exit 1
fi