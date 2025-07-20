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
# Shared test functions for OCS installation testing
#

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test result counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Test framework functions
start_test() {
    local test_name="$1"
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    log_info "Starting test: $test_name"
}

pass_test() {
    local test_name="$1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    log_success "Test passed: $test_name"
}

fail_test() {
    local test_name="$1"
    local error_msg="$2"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    log_error "Test failed: $test_name - $error_msg"
}

# Summary function
print_test_summary() {
    echo ""
    echo "========================================="
    echo "TEST SUMMARY"
    echo "========================================="
    echo "Total tests: $TESTS_TOTAL"
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $TESTS_FAILED"
    echo "Success rate: $(( TESTS_PASSED * 100 / TESTS_TOTAL ))%"
    echo "========================================="
    
    if [ $TESTS_FAILED -eq 0 ]; then
        log_success "All tests passed!"
        return 0
    else
        log_error "$TESTS_FAILED tests failed"
        return 1
    fi
}

# Wait for command to succeed with timeout
wait_for_command() {
    local command="$1"
    local timeout="${2:-300}"  # Default 5 minutes
    local interval="${3:-10}"  # Default 10 seconds
    local elapsed=0
    
    log_info "Waiting for command to succeed: $command"
    
    while [ $elapsed -lt $timeout ]; do
        if eval "$command" >/dev/null 2>&1; then
            log_success "Command succeeded after ${elapsed}s"
            return 0
        fi
        sleep $interval
        elapsed=$((elapsed + interval))
        
        if [ $((elapsed % 60)) -eq 0 ]; then
            log_info "Still waiting... (${elapsed}s elapsed)"
        fi
    done
    
    log_error "Command timed out after ${timeout}s: $command"
    return 1
}

# Check if OCS is installed
check_ocs_installed() {
    if [ -d "/opt/ocs/default/common" ] && [ -f "/opt/ocs/default/common/settings.sh" ]; then
        return 0
    else
        return 1
    fi
}

# Source OCS environment
source_ocs_env() {
    if [ -f "/opt/ocs/default/common/settings.sh" ]; then
        # shellcheck source=/dev/null
        . /opt/ocs/default/common/settings.sh
        return 0
    else
        log_error "OCS environment file not found"
        return 1
    fi
}

# Test OCS commands
test_ocs_command() {
    local command="$1"
    local test_name="$2"
    local expected_pattern="${3:-.*}"  # Optional pattern to match in output
    
    start_test "$test_name"
    
    if ! source_ocs_env; then
        fail_test "$test_name" "Could not source OCS environment"
        return 1
    fi
    
    local output
    if output=$(eval "$command" 2>&1); then
        if echo "$output" | grep -q "$expected_pattern"; then
            pass_test "$test_name"
            return 0
        else
            fail_test "$test_name" "Output does not match expected pattern: $expected_pattern"
            log_info "Actual output: $output"
            return 1
        fi
    else
        fail_test "$test_name" "Command failed: $command"
        log_info "Error output: $output"
        return 1
    fi
}

# Test job submission and completion
test_job_submission() {
    local job_command="$1"
    local test_name="$2"
    
    start_test "$test_name"
    
    if ! source_ocs_env; then
        fail_test "$test_name" "Could not source OCS environment"
        return 1
    fi
    
    # Submit job
    local job_output
    if job_output=$(qsub -sync y -b y "$job_command" 2>&1); then
        local job_id
        job_id=$(echo "$job_output" | grep "Your job" | awk '{print $3}')
        if [ -n "$job_id" ]; then
            pass_test "$test_name"
            log_info "Job $job_id completed successfully"
            return 0
        else
            fail_test "$test_name" "Could not extract job ID from output"
            log_info "qsub output: $job_output"
            return 1
        fi
    else
        fail_test "$test_name" "Job submission failed"
        log_info "qsub error: $job_output"
        return 1
    fi
}

# Save test report
save_test_report() {
    local hostname="$1"
    local test_type="$2"
    local report_file="/opt/reports/${hostname}_${test_type}_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "OCS Test Report for $hostname"
        echo "Test Type: $test_type"
        echo "Date: $(date)"
        echo "Hostname: $(hostname)"
        echo "OS Info: $(cat /etc/os-release 2>/dev/null | head -5)"
        echo "========================================="
        print_test_summary
    } > "$report_file"
    
    log_info "Test report saved to: $report_file"
}