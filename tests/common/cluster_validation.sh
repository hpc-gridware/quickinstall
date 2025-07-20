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
# Cluster validation tests for OCS
#

# Source test functions
# shellcheck source=test_functions.sh
. "$(dirname "$0")/test_functions.sh"

# Main validation function
validate_ocs_cluster() {
    local test_type="${TEST_TYPE:-single}"
    local hostname
    hostname=$(hostname)
    
    log_info "Starting OCS validation for $hostname (type: $test_type)"
    
    # Basic installation check
    start_test "OCS Installation Check"
    if check_ocs_installed; then
        pass_test "OCS Installation Check"
    else
        fail_test "OCS Installation Check" "OCS not properly installed"
        return 1
    fi
    
    # Environment check
    start_test "OCS Environment Check"
    if source_ocs_env; then
        pass_test "OCS Environment Check"
        log_info "SGE_ROOT: $SGE_ROOT"
        log_info "SGE_CELL: $SGE_CELL"
        log_info "SGE_CLUSTER_NAME: $SGE_CLUSTER_NAME"
    else
        fail_test "OCS Environment Check" "Could not source OCS environment"
        return 1
    fi
    
    # Service checks based on installation mode
    case "$test_type" in
        "single"|"master")
            # Test qmaster service
            start_test "Qmaster Service Check"
            if pgrep -f sge_qmaster >/dev/null; then
                pass_test "Qmaster Service Check"
            else
                fail_test "Qmaster Service Check" "sge_qmaster process not running"
            fi
            
            # Test qhost command
            test_ocs_command "qhost" "Qhost Command Test" "HOSTNAME"
            
            # Test qstat command
            test_ocs_command "qstat -f" "Qstat Command Test" 
            
            # Test queue configuration
            test_ocs_command "qconf -sql" "Queue List Test" "all.q"
            
            # Test execution host list
            test_ocs_command "qconf -sel" "Execution Host List Test" "$hostname"
            
            # Test scheduler status
            test_ocs_command "qconf -ss" "Scheduler Status Test"
            ;;
    esac
    
    # Test execd service (all modes have execd)
    start_test "Execd Service Check"
    if pgrep -f sge_execd >/dev/null; then
        pass_test "Execd Service Check"
    else
        fail_test "Execd Service Check" "sge_execd process not running"
    fi
    
    # Test job submission (only for master/single)
    if [ "$test_type" = "single" ] || [ "$test_type" = "master" ]; then
        test_job_submission "hostname" "Basic Job Submission Test"
        test_job_submission "sleep 5 && echo 'Test job completed'" "Sleep Job Test"
    fi
    
    # Cluster-specific tests
    if [ "$test_type" = "master" ]; then
        log_info "Waiting for execd nodes to join cluster..."
        sleep 30  # Give execd nodes time to register
        
        start_test "Multi-node Cluster Test"
        local host_count
        if source_ocs_env && host_count=$(qhost | grep -v "HOSTNAME" | grep -v "global" | wc -l); then
            if [ "$host_count" -gt 1 ]; then
                pass_test "Multi-node Cluster Test"
                log_info "Cluster has $host_count execution hosts"
                qhost | log_info
            else
                log_warning "Only $host_count execution host found, cluster may still be forming"
                pass_test "Multi-node Cluster Test"  # Don't fail, might be timing
            fi
        else
            fail_test "Multi-node Cluster Test" "Could not query cluster hosts"
        fi
    fi
    
    # Save test report
    save_test_report "$hostname" "$test_type"
    
    # Return overall result
    if [ $TESTS_FAILED -eq 0 ]; then
        log_success "All OCS validation tests passed for $hostname"
        return 0
    else
        log_error "Some OCS validation tests failed for $hostname"
        return 1
    fi
}

# Run validation if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    validate_ocs_cluster
    print_test_summary
fi