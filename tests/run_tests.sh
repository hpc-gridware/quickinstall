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
# Main test runner for OCS multi-distro testing
#
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default configuration
OCS_VERSION=${OCS_VERSION:-9.0.6}
OCS_CLUSTER_SECRET=${OCS_CLUSTER_SECRET:-$(openssl rand -hex 32 2>/dev/null || echo "a1b2c3d4e5f6789012345678901234567890123456789012345678901234abcd")}
TEST_TIMEOUT=${TEST_TIMEOUT:-1800}  # 30 minutes default

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Help function
show_help() {
    cat << EOF
OCS Multi-Distribution Testing Framework

Usage: $0 [OPTIONS] [TEST_SCENARIO]

OPTIONS:
    -v, --version VERSION    OCS version to test (default: $OCS_VERSION)
    -t, --timeout SECONDS    Test timeout in seconds (default: $TEST_TIMEOUT)
    -s, --secret SECRET      Cluster secret for multi-node tests
    -c, --cleanup           Clean up containers before running
    -h, --help              Show this help message

TEST_SCENARIOS:
    all                     Run all tests (single-node + cluster)
    single                  Run single-node tests only
    cluster                 Run cluster tests only
    rocky96                 Test Rocky 9.6 only
    ubuntu2204              Test Ubuntu 22.04 only  
    ubuntu2404              Test Ubuntu 24.04 only
    opensuse155             Test openSUSE Leap 15.5 only
    opensuse156             Test openSUSE Leap 15.6 only
    centos7                 Test CentOS 7 only
    build                   Build all images
    build SERVICE           Build specific image (e.g., ubuntu2204-single)
    clean                   Clean up all containers and images

Examples:
    $0 all                  # Run all tests
    $0 single               # Run single-node tests only
    $0 cluster              # Run cluster tests only  
    $0 rocky96              # Test Rocky 9.6 only (builds only required image)
    $0 ubuntu2204           # Test Ubuntu 22.04 only (builds only required image)
    $0 build ubuntu2204-single  # Build only Ubuntu 22.04 image
    $0 --version 9.0.7 all  # Test OCS 9.0.7 across all distributions

EOF
}

# Cleanup function
cleanup_containers() {
    log_info "Cleaning up existing containers and volumes..."
    
    # Stop and remove containers from all compose files
    docker-compose -f docker-compose.yml down -v --remove-orphans 2>/dev/null || true
    docker-compose -f docker-compose.single.yml down -v --remove-orphans 2>/dev/null || true
    docker-compose -f docker-compose.cluster.yml down -v --remove-orphans 2>/dev/null || true
    
    # Remove any leftover containers
    docker ps -a --filter "name=ocs-test-" -q | xargs docker rm -f 2>/dev/null || true
    
    # Clean up volumes
    docker volume ls --filter "name=tests_ocs-shared" -q | xargs docker volume rm 2>/dev/null || true
    
    log_success "Cleanup completed"
}

# Build images
build_images() {
    local services=("$@")  # Optional specific services to build
    
    if [ ${#services[@]} -eq 0 ]; then
        log_info "Building all Docker images..."
        # Build images from single compose file (contains all image definitions)
        if docker-compose -f docker-compose.single.yml build; then
            log_success "All images built successfully"
            return 0
        else
            log_error "Failed to build images"
            return 1
        fi
    else
        log_info "Building Docker images for: ${services[*]}"
        export OCS_VERSION
        export OCS_CLUSTER_SECRET
        
        # Build specific services using direct docker build to avoid shared context issues
        for service in "${services[@]}"; do
            local dockerfile=""
            local image_tag=""
            
            case "$service" in
                "rocky96-single")
                    dockerfile="rocky9.6/Dockerfile"
                    image_tag="tests_rocky96-single"
                    ;;
                "ubuntu2204-single")
                    dockerfile="ubuntu22.04/Dockerfile"
                    image_tag="tests_ubuntu2204-single"
                    ;;
                "ubuntu2404-single")
                    dockerfile="ubuntu24.04/Dockerfile"
                    image_tag="tests_ubuntu2404-single"
                    ;;
                "opensuse155-single")
                    dockerfile="opensuse-leap15.5/Dockerfile"
                    image_tag="tests_opensuse155-single"
                    ;;
                "opensuse156-single")
                    dockerfile="opensuse-leap15.6/Dockerfile"
                    image_tag="tests_opensuse156-single"
                    ;;
                "centos7-single")
                    dockerfile="centos7/Dockerfile"
                    image_tag="tests_centos7-single"
                    ;;
                *)
                    log_error "Unknown service: $service"
                    return 1
                    ;;
            esac
            
            log_info "Building $service using $dockerfile..."
            if docker build -f "$dockerfile" -t "$image_tag" .; then
                log_success "Built $service successfully"
            else
                log_error "Failed to build $service"
                return 1
            fi
        done
        
        log_success "Selected images built successfully"
        return 0
    fi
}

# Wait for container and run tests
wait_and_test_container() {
    local container_name="$1"
    local test_timeout="$2"
    
    log_info "Waiting for container $container_name to be ready..."
    
    # Wait for container to be running
    local count=0
    while [ $count -lt 60 ]; do  # 5 minute max wait
        if docker ps --filter "name=$container_name" --filter "status=running" | grep -q "$container_name"; then
            break
        fi
        sleep 5
        count=$((count + 1))
    done
    
    if ! docker ps --filter "name=$container_name" --filter "status=running" | grep -q "$container_name"; then
        log_error "Container $container_name is not running"
        return 1
    fi
    
    # Run the installation and tests inside container
    log_info "Running OCS installation and tests in $container_name..."
    
    # Use a cross-platform timeout approach
    if command -v timeout >/dev/null 2>&1; then
        # Linux/GNU timeout
        if timeout "$test_timeout" docker exec "$container_name" /opt/test-scripts/install_and_test.sh; then
            log_success "Tests completed successfully in $container_name"
            return 0
        else
            log_error "Tests failed in $container_name"
        fi
    elif command -v gtimeout >/dev/null 2>&1; then
        # macOS with GNU coreutils (brew install coreutils)
        if gtimeout "$test_timeout" docker exec "$container_name" /opt/test-scripts/install_and_test.sh; then
            log_success "Tests completed successfully in $container_name"
            return 0
        else
            log_error "Tests failed in $container_name"
        fi
    else
        # Fallback without timeout (not ideal but works)
        log_warning "No timeout command available, running without timeout"
        if docker exec "$container_name" /opt/test-scripts/install_and_test.sh; then
            log_success "Tests completed successfully in $container_name"
            return 0
        else
            log_error "Tests failed in $container_name"
        fi
    fi
    
    # Show container logs for debugging if we reach here (error case)
    log_info "Container logs for $container_name:"
    docker logs --tail 50 "$container_name" || true
    
    return 1
}

# Run single-node tests
run_single_node_tests() {
    log_info "Starting single-node tests for all distributions..."
    
    local services=(
        "rocky96-single"
        "ubuntu2204-single" 
        "ubuntu2404-single"
        "opensuse155-single"
        "opensuse156-single"
        "centos7-single"
    )
    
    local failed_tests=0
    
    export OCS_VERSION
    export OCS_CLUSTER_SECRET
    
    # Start all single-node containers
    log_info "Starting single-node test containers..."
    if ! docker-compose -f docker-compose.single.yml up -d "${services[@]}"; then
        log_error "Failed to start single-node test containers"
        return 1
    fi
    
    # Test each container
    for service in "${services[@]}"; do
        local container_name="ocs-test-$service"
        if ! wait_and_test_container "$container_name" "$TEST_TIMEOUT"; then
            failed_tests=$((failed_tests + 1))
        fi
    done
    
    # Stop containers
    docker-compose -f docker-compose.single.yml stop "${services[@]}" || true
    
    if [ $failed_tests -eq 0 ]; then
        log_success "All single-node tests passed"
        return 0
    else
        log_error "$failed_tests single-node tests failed"
        return 1
    fi
}

# Run cluster tests
run_cluster_tests() {
    log_info "Starting cluster tests (openSUSE 15.6 master + openSUSE 15.5/CentOS 7 execd)..."
    
    local services=(
        "opensuse156-master"
        "opensuse155-execd"
        "centos7-execd"
    )
    
    export OCS_VERSION
    export OCS_CLUSTER_SECRET
    
    # Build only the required images for cluster testing
    log_info "Building cluster images: opensuse156-master, opensuse155-execd, centos7-execd"
    if ! docker-compose -f docker-compose.cluster.yml build opensuse156-master opensuse155-execd centos7-execd; then
        log_error "Failed to build cluster images"
        return 1
    fi
    log_success "Cluster images built successfully"
    
    # Start cluster containers
    log_info "Starting cluster test containers..."
    if ! docker-compose -f docker-compose.cluster.yml up -d "${services[@]}"; then
        log_error "Failed to start cluster test containers"
        return 1
    fi
    
    # Test master node first
    log_info "Testing master node..."
    if ! wait_and_test_container "ocs-test-opensuse156-master" "$TEST_TIMEOUT"; then
        log_error "Master node test failed"
        docker-compose -f docker-compose.cluster.yml stop "${services[@]}" || true
        return 1
    fi
    
    # Test execd nodes
    local failed_execd=0
    for service in "opensuse155-execd" "centos7-execd"; do
        local container_name="ocs-test-$service"
        log_info "Testing execd node: $service"
        if ! wait_and_test_container "$container_name" "$TEST_TIMEOUT"; then
            failed_execd=$((failed_execd + 1))
        fi
    done
    
    # Final cluster validation on master
    log_info "Running final cluster validation..."
    sleep 30  # Give cluster time to stabilize
    
    if docker exec "ocs-test-opensuse156-master" /opt/test-scripts/cluster_validation.sh; then
        log_success "Final cluster validation passed"
    else
        log_warning "Final cluster validation had issues"
        failed_execd=$((failed_execd + 1))
    fi
    
    # Stop containers
    docker-compose -f docker-compose.cluster.yml stop "${services[@]}" || true
    
    if [ $failed_execd -eq 0 ]; then
        log_success "All cluster tests passed"
        return 0
    else
        log_error "Some cluster tests failed"
        return 1
    fi
}

# Run specific distribution test
run_single_distro_test() {
    local distro="$1"
    
    case "$distro" in
        "rocky96")
            local service="rocky96-single"
            ;;
        "ubuntu2204")
            local service="ubuntu2204-single"
            ;;
        "ubuntu2404")
            local service="ubuntu2404-single"
            ;;
        "opensuse155")
            local service="opensuse155-single"
            ;;
        "opensuse156")
            local service="opensuse156-single"
            ;;
        "centos7")
            local service="centos7-single"
            ;;
        *)
            log_error "Unknown distribution: $distro"
            return 1
            ;;
    esac
    
    log_info "Starting test for $distro..."
    
    export OCS_VERSION
    export OCS_CLUSTER_SECRET
    
    # Build only the required image
    if ! build_images "$service"; then
        log_error "Failed to build image for $distro"
        return 1
    fi
    
    # Start container
    if ! docker-compose -f docker-compose.single.yml up -d "$service"; then
        log_error "Failed to start container for $distro"
        return 1
    fi
    
    # Run test
    local container_name="ocs-test-$service"
    if wait_and_test_container "$container_name" "$TEST_TIMEOUT"; then
        log_success "Test passed for $distro"
        docker-compose -f docker-compose.single.yml stop "$service" || true
        return 0
    else
        log_error "Test failed for $distro"
        docker-compose -f docker-compose.single.yml stop "$service" || true
        return 1
    fi
}

# Generate test report
generate_report() {
    local report_file="reports/test_summary_$(date +%Y%m%d_%H%M%S).txt"
    
    log_info "Generating test report: $report_file"
    
    {
        echo "OCS Multi-Distribution Test Report"
        echo "=================================="
        echo "Date: $(date)"
        echo "OCS Version: $OCS_VERSION"
        echo "Test Duration: $((SECONDS / 60)) minutes"
        echo ""
        echo "Individual Test Reports:"
        echo "------------------------"
        find reports -name "*.txt" -type f -exec echo "- {}" \; 2>/dev/null || echo "No individual reports found"
    } > "$report_file"
    
    log_success "Test report generated: $report_file"
}

# Main function
main() {
    local test_scenario="${1:-all}"
    local start_time=$SECONDS
    
    # Change to tests directory
    cd "$(dirname "$0")"
    
    # Create reports directory
    mkdir -p reports
    
    case "$test_scenario" in
        "build")
            if [ $# -gt 1 ]; then
                shift  # Remove 'build' argument
                build_images "$@"  # Build specific services
            else
                build_images  # Build all images
            fi
            ;;
        "clean")
            cleanup_containers
            ;;
        "all")
            cleanup_containers
            build_images
            
            local single_result=0
            local cluster_result=0
            
            run_single_node_tests || single_result=1
            run_cluster_tests || cluster_result=1
            
            generate_report
            
            if [ $single_result -eq 0 ] && [ $cluster_result -eq 0 ]; then
                log_success "All tests completed successfully!"
                exit 0
            else
                log_error "Some tests failed"
                exit 1
            fi
            ;;
        "single")
            cleanup_containers
            build_images
            run_single_node_tests
            generate_report
            ;;
        "cluster")
            cleanup_containers
            run_cluster_tests
            generate_report
            ;;
        "rocky96"|"ubuntu2204"|"ubuntu2404"|"opensuse155"|"opensuse156"|"centos7")
            cleanup_containers
            run_single_distro_test "$test_scenario"
            generate_report
            ;;
        "-h"|"--help"|"help")
            show_help
            ;;
        *)
            log_error "Unknown test scenario: $test_scenario"
            show_help
            exit 1
            ;;
    esac
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--version)
            OCS_VERSION="$2"
            shift 2
            ;;
        -t|--timeout)
            TEST_TIMEOUT="$2"
            shift 2
            ;;
        -s|--secret)
            OCS_CLUSTER_SECRET="$2"
            shift 2
            ;;
        -c|--cleanup)
            cleanup_containers
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            # This is the test scenario
            break
            ;;
    esac
done

# Export environment variables for docker-compose
export OCS_VERSION
export OCS_CLUSTER_SECRET

# Run main function with remaining arguments
main "$@"