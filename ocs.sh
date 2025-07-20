#!/bin/sh

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

# Improved Open Cluster Scheduler Installation Script
# Works across Linux distributions. Multi-node support when /opt/ocs 
# is shared.
# 
# Usage:
#   curl -s <script_url> | sh                    # Installs default version (full cluster mode)
#   curl -s <script_url> | OCS_VERSION=9.0.6 sh  # Installs specific version
#   curl -s <script_url> | OCS_INSTALL_MODE=single sh  # Single-node installation (testing)
#   curl -s <script_url> | OCS_INSTALL_MODE=execd OCS_CLUSTER_SECRET=a1b2c3... sh  # Execd-only installation

set -e  # Exit on error
#set -u  # Treat unset variables as errors

# Default configuration - can be overridden by environment variables
OCS_VERSION="${OCS_VERSION:-9.0.6}"
OCS_INSTALL_MODE="${OCS_INSTALL_MODE:-full}"  # full|single|execd
OCS_CLUSTER_SECRET="${OCS_CLUSTER_SECRET:-}"  # required for execd mode (64-char hex)

echo "Starting Open Cluster Scheduler installation (version: $OCS_VERSION)..."

# Function to get download URLs and MD5 checksums based on version
get_download_info() {
    local version="$1"
    local arch="$2"  # lx-amd64, lx-arm64, ulx-amd64
    
    case "$version" in
        "9.0.5")
            case "$arch" in
                "lx-amd64")
                    echo "https://www.hpc-gridware.com/download/10529/?tmstv=1745334305#96a81d322409d1d1203e649eb13914e2"
                    ;;
                "ulx-amd64")
                    echo "https://www.hpc-gridware.com/download/10535/?tmstv=1745334305#f1fb444a7dfc214d5bbe1c73368a758d"
                    ;;
                "doc")
                    echo "https://www.hpc-gridware.com/download/10543/?tmstv=1745334305#a8e18a08daf99f36529b6f8871e2c21c"
                    ;;
                "common")
                    echo "https://www.hpc-gridware.com/download/10541/?tmstv=1745334305#6806cd518b9c13538e118cabeeb9841f"
                    ;;
                *)
                    echo ""
                    ;;
            esac
            ;;
        "9.0.6")
            case "$arch" in
                "lx-amd64")
                    echo "https://www.hpc-gridware.com/download/10646/?tmstv=1749092703#1e3b837be3418675613246fb0eb18b84"
                    ;;
                "lx-arm64")
                    echo "https://www.hpc-gridware.com/download/10648/?tmstv=1749092703#cd767e2a7fe77fdfba2cbc5625208b8a"
                    ;;
                "ulx-amd64")
                    echo "https://www.hpc-gridware.com/download/10652/?tmstv=1749092703#598f62a4f56ed75fae2ab66be5b1c360"
                    ;;
                "doc")
                    echo "https://www.hpc-gridware.com/download/10656/?tmstv=1749092703#8aadb37ec72aa1025a0dbd644974d51f"
                    ;;
                "common")
                    echo "https://www.hpc-gridware.com/download/10654/?tmstv=1749092703#d8e82a22ca295d221ff3d91ebdf9c74d"
                    ;;
                *)
                    echo ""
                    ;;
            esac
            ;;
        "9.0.7")
            case "$arch" in
                "lx-amd64")
                    echo "https://www.hpc-gridware.com/download/10802/?tmstv=1751900704#ef6da1034611894b4fad7224835ae91c"
                    ;;
                "lx-arm64")
                    echo "https://www.hpc-gridware.com/download/10804/?tmstv=1751900704#99cdd45777e571065a5deab7709b2ca5"
                    ;;
                "ulx-amd64")
                    echo "https://www.hpc-gridware.com/download/10808/?tmstv=1751900704#f62a2338f5b3fe56a9ae1fa187d2d111"
                    ;;
                "doc")
                    echo "https://www.hpc-gridware.com/download/10818/?tmstv=1751900704#111cfdf48fbd4c6e7c8716c6427aca75"
                    ;;
                "common")
                    echo "https://www.hpc-gridware.com/download/10816/?tmstv=1751900704#1c093208d295959a978c142a4943de7a"
                    ;;
                *)
                    echo ""
                    ;;
            esac
            ;;
        *)
            echo "ERROR: Unsupported OCS version: $version" >&2
            echo "Supported versions: 9.0.5, 9.0.6, 9.0.7" >&2
            exit 1
            ;;
    esac
}

# Function to detect system architecture
detect_architecture() {
    local arch="$(uname -m)"
    local os_release=""
    
    # Check if it's an old Linux system (like CentOS 7)
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [ "$ID" = "centos" ] && [ "${VERSION_ID%%.*}" -le 7 ]; then
            # Try ulx-amd64 first, but allow fallback to lx-amd64
            echo "ulx-amd64"
            return
        fi
        # Add more old Linux checks here if needed
    fi
    
    # Map architecture
    case "$arch" in
        x86_64)
            echo "lx-amd64"
            ;;
        aarch64|arm64)
            echo "lx-arm64"
            ;;
        *)
            echo "ERROR: Unsupported architecture: $arch" >&2
            exit 1
            ;;
    esac
}

# Function to detect system architecture with fallback for compatibility issues
detect_architecture_with_fallback() {
    local primary_arch="$(detect_architecture)"
    
    # For CentOS 7, provide fallback from ulx-amd64 to lx-amd64 if needed
    if [ "$primary_arch" = "ulx-amd64" ]; then
        echo "$primary_arch"
        return
    fi
    
    echo "$primary_arch"
}

# Function to install packages based on the package manager
install_packages() {
    local epel_installed=0
    
    if command -v apt >/dev/null 2>&1; then
        echo "Detected apt package manager"
        sudo apt update
        # Install packages individually to avoid word splitting issues
        sudo apt install -y git tar binutils sudo make wget bash openssl
        
        # On Ubuntu, the package names are libtirpc3 and libtirpc-dev
        echo "Installing libtirpc packages..."
        sudo apt install -y libtirpc3 libtirpc-dev
    elif command -v dnf >/dev/null 2>&1; then
        echo "Detected dnf package manager"
        
        # First install dnf-plugins-core if not already installed
        if ! rpm -q dnf-plugins-core >/dev/null 2>&1; then
            echo "Installing dnf-plugins-core for repository management..."
            sudo dnf install -y dnf-plugins-core
        fi
        
        # Try to install packages directly first
        sudo dnf install -y git tar binutils sudo make wget bash openssl
        
        echo "Enabling CRB/CodeReady repo for development packages..."
        . /etc/os-release
        if [ "${ID}" = "ol" ] && [ "${VERSION_ID%%.*}" = "9" ]; then
            sudo dnf config-manager --set-enabled ol9_codeready_builder
        else
            sudo dnf config-manager --set-enabled crb || sudo dnf config-manager --set-enabled powertools || true
        fi
        
        # Install libtirpc and libtirpc-devel directly from the repository
        echo "Installing libtirpc from repository..."
        sudo dnf install -y libtirpc libtirpc-devel
        
        # Try to install screen, if it fails, add EPEL repo
        if ! sudo dnf install -y screen; then
            echo "Screen package not found in default repositories, adding EPEL..."
            
            # Install EPEL repository
            if sudo dnf install -y epel-release; then
                echo "EPEL repository installed successfully"
                epel_installed=1
            else
                echo "WARNING: Failed to install EPEL repository"
            fi
            
            # Try to install screen again if EPEL was installed
            if [ $epel_installed -eq 1 ]; then
                if ! sudo dnf install -y screen; then
                    echo "WARNING: Screen package not available even with EPEL. Continuing without screen..."
                fi
            fi
        fi
    elif command -v yum >/dev/null 2>&1; then
        echo "Detected yum package manager"
        sudo yum install -y git tar binutils sudo make wget bash openssl
        
        # Enable optional repositories
        echo "Enabling required repositories..."
        sudo yum install -y yum-utils
        sudo yum-config-manager --enable powertools || sudo yum-config-manager --enable crb || true
        
        # Install libtirpc directly
        sudo yum install -y libtirpc libtirpc-devel
        
        # Try to install screen, if it fails, add EPEL repo
        if ! sudo yum install -y screen; then
            echo "Screen package not found in default repositories, adding EPEL..."
            
            # Install EPEL repository
            if sudo yum install -y epel-release; then
                echo "EPEL repository installed successfully"
                epel_installed=1
            else
                echo "WARNING: Failed to install EPEL repository"
            fi
            
            # Try to install screen again if EPEL was installed
            if [ $epel_installed -eq 1 ]; then
                if ! sudo yum install -y screen; then
                    echo "WARNING: Screen package not available even with EPEL. Continuing without screen..."
                fi
            fi
        fi
    elif command -v pacman >/dev/null 2>&1; then
        echo "Detected pacman package manager"
        sudo pacman -Sy --noconfirm git tar binutils sudo make wget bash openssl screen libtirpc
    elif command -v zypper >/dev/null 2>&1; then
        echo "Detected zypper package manager"
        # Detect distribution and version
        if [ -f /etc/os-release ]; then
          . /etc/os-release
          DISTID=$ID
          DISTVERSION=${VERSION_ID%%.*}
        else
          echo "ERROR: Cannot detect SUSE distribution version."
          exit 1
        fi

        # Default package list
        packages="git tar binutils sudo make wget bash openssl screen libtirpc libtirpc-devel"

        if [ "$DISTID" = "sles" ]; then
          echo "Detected SUSE Linux Enterprise Server $DISTVERSION"
          # Register Desktop Applications module FIRST
          sudo SUSEConnect -p sle-module-desktop-applications/"${VERSION_ID}"/x86_64 || \
            sudo SUSEConnect -p sle-module-desktop-applications/15/x86_64
          # Register Development Tools module
          sudo SUSEConnect -p sle-module-development-tools/"${VERSION_ID}"/x86_64 || \
            sudo SUSEConnect -p sle-module-development-tools/15/x86_64
          packages="git-core tar binutils sudo make wget bash openssl screen libtirpc3 libtirpc-devel"
        elif [ "$DISTID" = "opensuse-leap" ]; then
          echo "Detected openSUSE Leap $DISTVERSION"
          # On openSUSE, package names are as expected
          packages="git tar binutils sudo make wget bash openssl screen libtirpc3 libtirpc-devel"
        else
          echo "WARNING: Unknown SUSE variant; attempting with default package names."
        fi

        # Install packages with zypper
        sudo zypper install -y --no-recommends $packages

        # Check for errors if critical packages are missing
        if ! rpm -q libtirpc-devel > /dev/null; then
          echo "ERROR: libtirpc-devel could not be installed."
          exit 1
        fi
        if ! command -v git >/dev/null 2>&1; then
          echo "ERROR: git could not be installed."
          exit 1
        fi
        if ! command -v openssl >/dev/null 2>&1; then
          echo "ERROR: openssl could not be installed."
          exit 1
        fi
    else
        echo "ERROR: Unsupported package manager. Please install the following packages manually:"
        echo "git tar binutils sudo make wget bash openssl screen libtirpc libtirpc-devel"
        exit 1
    fi
}

# Discover qmaster hostname from shared filesystem
discover_qmaster() {
    echo "Discovering qmaster hostname from shared filesystem..."
    
    local qmaster_file="/opt/ocs/.cluster_info/qmaster_hostname"
    local timeout=1800  # 30 minutes
    local elapsed=0
    
    # Wait for qmaster hostname file to appear
    while [ $elapsed -lt $timeout ]; do
        if [ -f "$qmaster_file" ]; then
            QMASTER_HOSTNAME=$(head -n1 "$qmaster_file" 2>/dev/null | tr -d '\n\r')
            if [ -n "$QMASTER_HOSTNAME" ]; then
                echo "PASS: Discovered qmaster hostname: $QMASTER_HOSTNAME"
                return 0
            fi
        fi
        sleep 10
        elapsed=$((elapsed + 10))
    done
    
    echo "ERROR: Timeout waiting for qmaster hostname discovery"
    exit 1
}

# Validate shared filesystem for execd installation
validate_shared_filesystem() {
    echo "Validating shared filesystem for execd installation..."
    
    # Check if /opt/ocs is a mounted filesystem
    if ! mountpoint -q /opt/ocs 2>/dev/null; then
        echo "WARNING: /opt/ocs is not detected as a mounted filesystem"
        echo "Proceeding anyway - ensure /opt/ocs is shared between master and execd nodes"
    else
        echo "PASS: /opt/ocs is a mounted filesystem"
    fi
    
    # Check if directory exists and is accessible
    if [ ! -d "/opt/ocs" ]; then
        echo "ERROR: /opt/ocs directory does not exist"
        echo "Ensure shared filesystem is mounted at /opt/ocs"
        exit 1
    fi
    
    # Check write permissions
    if ! [ -w "/opt/ocs" ]; then
        echo "ERROR: No write access to /opt/ocs directory"
        echo "Check filesystem permissions and mount options"
        exit 1
    fi
    
    echo "PASS: Shared filesystem validation completed"
}

# Validate basic prerequisites for execd-only installation (before package installation)
validate_execd_basic_prerequisites() {
    echo "Validating basic prerequisites for execd-only installation..."
    
    # Check required environment variables
    if [ -z "$OCS_CLUSTER_SECRET" ]; then
        echo "ERROR: OCS_CLUSTER_SECRET must be set for execd-only installation"
        echo "Usage: OCS_INSTALL_MODE=execd OCS_CLUSTER_SECRET=your-64-char-hex-key $0"
        exit 1
    fi
    
    # Validate cluster secret format (64 character hex)
    if ! echo "$OCS_CLUSTER_SECRET" | grep -qE '^[a-fA-F0-9]{64}$'; then
        echo "ERROR: OCS_CLUSTER_SECRET must be a 64-character hexadecimal string"
        echo "Generate with: openssl rand -hex 32"
        exit 1
    fi
    
    echo "Basic prerequisites validation passed for execd-only installation"
}

# Validate advanced prerequisites for execd-only installation (after package installation)
validate_execd_advanced_prerequisites() {
    echo "Validating advanced prerequisites for execd-only installation..."
    
    # Check if openssl is available for HMAC operations
    if ! command -v openssl >/dev/null 2>&1; then
        echo "ERROR: openssl command not found, required for secure cluster authentication"
        echo "Please install openssl package"
        exit 1
    fi
    
    validate_shared_filesystem
    discover_qmaster
    
    echo "Advanced prerequisites validation passed for execd-only installation"
}

# Wait for master installation to complete
wait_for_master_installation() {
    echo "Waiting for master installation to complete..."
    
    local completion_flag="/opt/ocs/.cluster_info/installation_complete"
    local timeout=1800  # 30 minutes
    local elapsed=0
    
    while [ $elapsed -lt $timeout ]; do
        if [ -f "$completion_flag" ]; then
            echo "PASS: Master installation detected as complete"
            return 0
        fi
        sleep 10
        elapsed=$((elapsed + 10))
        
        # Progress indicator every 2 minutes
        if [ $((elapsed % 120)) -eq 0 ]; then
            echo "Still waiting for master installation... (${elapsed}s elapsed)"
        fi
    done
    
    echo "ERROR: Timeout waiting for master installation to complete"
    exit 1
}

# Create secure registration request with HMAC signature
create_secure_registration_request() {
    echo "Creating secure admin host registration request..."
    
    local hostname="$(hostname)"
    local timestamp="$(date +%s)"
    local ip_address=$(hostname -I | awk '{print $1}')
    local request_id="${hostname}_${timestamp}_$$"
    
    # Create message to sign
    local message="${hostname}:${timestamp}:${ip_address}"
    
    # Create HMAC signature using cluster secret
    local signature=$(printf '%s' "$message" | openssl dgst -sha256 -hmac "$OCS_CLUSTER_SECRET" -binary | base64)
    
    # Create request file with secure permissions
    local request_dir="/opt/ocs/.cluster_management/registration_requests"
    local request_file="$request_dir/$request_id"
    
    sudo mkdir -p "$request_dir"
    sudo chmod 755 /opt/ocs/.cluster_management
    
    # Write request with signature
    sudo tee "$request_file" > /dev/null << EOF
HOSTNAME=$hostname
TIMESTAMP=$timestamp
IP_ADDRESS=$ip_address
MESSAGE=$message
SIGNATURE=$signature
EOF
    
    sudo chmod 600 "$request_file"
    echo "PASS: Registration request created: $request_id"
}

# Wait for admin host registration approval
wait_for_registration_approval() {
    echo "Waiting for admin host registration approval..."
    
    local hostname="$(hostname)"
    local approved_file="/opt/ocs/.cluster_management/registration_approved/$hostname"
    local rejected_file="/opt/ocs/.cluster_management/registration_rejected/$hostname"
    local timeout=600  # 10 minutes
    local elapsed=0
    
    while [ $elapsed -lt $timeout ]; do
        if [ -f "$approved_file" ]; then
            echo "PASS: Admin host registration approved"
            return 0
        elif [ -f "$rejected_file" ]; then
            echo "ERROR: Admin host registration rejected"
            if [ -r "$rejected_file" ]; then
                echo "Reason: $(cat "$rejected_file")"
            fi
            exit 1
        fi
        sleep 15
        elapsed=$((elapsed + 15))
        
        # Progress indicator every 2 minutes
        if [ $((elapsed % 120)) -eq 0 ]; then
            echo "Still waiting for registration approval... (${elapsed}s elapsed)"
        fi
    done
    
    echo "ERROR: Timeout waiting for admin host registration approval"
    exit 1
}

# Register admin host using secure HMAC-signed request
register_admin_host() {
    echo "Initiating secure admin host registration..."
    
    create_secure_registration_request
    wait_for_registration_approval
    
    echo "Admin host registration completed successfully"
}

# Function to verify MD5 checksum of downloaded file
verify_checksum() {
    local file="$1"
    local expected_md5="$2"
    
    if ! command -v md5sum >/dev/null 2>&1; then
        echo "ERROR: md5sum command not found"
        exit 1
    fi
    
    echo "Verifying checksum for $file..."
    local actual_md5="$(md5sum "$file" | cut -d' ' -f1)"
    if [ "$actual_md5" = "$expected_md5" ]; then
        echo "PASS: Checksum verified for $file"
        return 0
    else
        echo "ERROR: Checksum mismatch for $file"
        echo "Expected: $expected_md5"
        echo "Actual: $actual_md5"
        exit 1
    fi
}

# Check wget capabilities
get_wget_flags() {
    # Check if wget supports --show-progress
    if wget --help 2>/dev/null | grep -q -- '--show-progress'; then
        echo "-q --show-progress"
    else
        # Fallback for older wget versions
        echo "-q"
    fi
}

# Setup directories
setup_directories() {
    echo "Setting up installation directories..."
    # No need to create download directory here as we re-create it in download_files
    sudo mkdir -p /opt/ocs
}

# Download installation files
download_files() {
    echo "Downloading Open Cluster Scheduler $OCS_VERSION files..."
    
    # Detect system architecture
    local sys_arch="$(detect_architecture)"
    local fallback_arch=""
    
    # Set up fallback for CentOS 7 compatibility issues
    if [ "$sys_arch" = "ulx-amd64" ]; then
        fallback_arch="lx-amd64"
        echo "Detected system architecture: $sys_arch (fallback: $fallback_arch for compatibility)"
    else
        echo "Detected system architecture: $sys_arch"
    fi
    
    # Get appropriate wget flags for this system
    local wget_flags="$(get_wget_flags)"
    
    # Use the local directory for downloads
    local download_dir="./ocs_downloads"
    
    # Clean up existing downloads
    echo "Cleaning up existing downloads..."
    rm -rf "$download_dir"
    mkdir -p "$download_dir"
    
    cd "$download_dir"
    
    # Download architecture-specific binary package
    local bin_info=$(get_download_info "$OCS_VERSION" "$sys_arch")
    if [ -n "$bin_info" ]; then
        local bin_url=$(echo "$bin_info" | cut -d'#' -f1)
        local bin_checksum=$(echo "$bin_info" | cut -d'#' -f2)
        echo "Downloading $sys_arch binary package..."
        wget $wget_flags -k --content-disposition "$bin_url"
        
        # Find the downloaded file and verify checksum
        local downloaded_file=$(ls -t ocs-*-bin-${sys_arch}.tar.gz 2>/dev/null | head -n1)
        if [ -f "$downloaded_file" ]; then
            verify_checksum "$downloaded_file" "$bin_checksum"
        else
            echo "ERROR: Could not find downloaded binary file for $sys_arch"
            exit 1
        fi
    else
        echo "ERROR: No valid URL for $sys_arch binary package for version $OCS_VERSION"
        exit 1
    fi
    
    # For ARM64 systems with version 9.0.6+, also check if lx-arm64 is available
    if [ "$sys_arch" = "lx-amd64" ] && [ "$OCS_VERSION" != "9.0.5" ]; then
        local arm64_info=$(get_download_info "$OCS_VERSION" "lx-arm64")
        if [ -n "$arm64_info" ]; then
            echo "Note: ARM64 binary is also available for this version"
        fi
    fi
    
    # Download common packages
    for pkg in "doc" "common"; do
        local pkg_info=$(get_download_info "$OCS_VERSION" "$pkg")
        if [ -n "$pkg_info" ]; then
            local pkg_url=$(echo "$pkg_info" | cut -d'#' -f1)
            local pkg_checksum=$(echo "$pkg_info" | cut -d'#' -f2)
            echo "Downloading $pkg package..."
            wget $wget_flags -k --content-disposition "$pkg_url"
            
            # Find the downloaded file and verify checksum
            local downloaded_file=$(ls -t ocs-*-${pkg}.tar.gz 2>/dev/null | head -n1)
            if [ -f "$downloaded_file" ]; then
                verify_checksum "$downloaded_file" "$pkg_checksum"
            else
                echo "ERROR: Could not find downloaded $pkg file"
                exit 1
            fi
        else
            echo "ERROR: No valid URL for $pkg package for version $OCS_VERSION"
            exit 1
        fi
    done
    
    echo "Extracting files to installation directory..."
    for file in ocs-*.tar.gz; do
        if [ -f "$file" ]; then
            echo "  Extracting $file..."
            sudo tar xpf "$file" -C /opt/ocs/
        fi
    done
    
    cd - > /dev/null
}

# Download architecture-specific binaries for execd node
download_execd_binaries() {
    local execd_arch="$1"
    echo "Downloading $execd_arch binaries for execd node..."
    
    # Get appropriate wget flags for this system
    local wget_flags="$(get_wget_flags)"
    
    # Use a temporary directory for execd-specific downloads
    local execd_download_dir="/tmp/ocs_execd_downloads_$$"
    
    # Clean up any existing downloads
    echo "Setting up temporary download directory..."
    rm -rf "$execd_download_dir"
    mkdir -p "$execd_download_dir"
    
    cd "$execd_download_dir"
    
    # Download architecture-specific binary package
    local bin_info=$(get_download_info "$OCS_VERSION" "$execd_arch")
    if [ -n "$bin_info" ]; then
        local bin_url=$(echo "$bin_info" | cut -d'#' -f1)
        local bin_checksum=$(echo "$bin_info" | cut -d'#' -f2)
        echo "Downloading $execd_arch binary package..."
        wget $wget_flags -k --content-disposition "$bin_url"
        
        # Find the downloaded file and verify checksum
        local downloaded_file=$(ls -t ocs-*-bin-${execd_arch}.tar.gz 2>/dev/null | head -n1)
        if [ -f "$downloaded_file" ]; then
            verify_checksum "$downloaded_file" "$bin_checksum"
            
            # Extract binaries to the shared filesystem
            echo "Extracting $execd_arch binaries to shared filesystem..."
            sudo tar xpf "$downloaded_file" -C "${MOUNT_DIR}/"
            
            echo "Successfully installed $execd_arch binaries for execd"
        else
            echo "ERROR: Could not find downloaded binary file for $execd_arch"
            cd - > /dev/null
            rm -rf "$execd_download_dir"
            return 1
        fi
    else
        echo "ERROR: No valid URL for $execd_arch binary package for version $OCS_VERSION"
        cd - > /dev/null
        rm -rf "$execd_download_dir"
        return 1
    fi
    
    # Clean up temporary downloads
    cd - > /dev/null
    rm -rf "$execd_download_dir"
    
    echo "Architecture-specific binary download completed for $execd_arch"
    return 0
}

# Create autoinstall template for full installation
create_autoinstall_template() {
    local hostname="$(hostname)"
    local template_file="$(pwd)/autoinstall.template"
    
    cat > "$template_file" << EOF
SGE_ROOT="/opt/ocs"
SGE_QMASTER_PORT="6444"
SGE_EXECD_PORT="6445"
SGE_ENABLE_SMF="false"
SGE_CLUSTER_NAME="p6444"
CELL_NAME="default"
ADMIN_USER="root"
QMASTER_SPOOL_DIR="/opt/ocs/default/spool/master"
EXECD_SPOOL_DIR="/opt/ocs/default/spool/execd"
GID_RANGE="20000-20200"
SPOOLING_METHOD="classic"
DB_SPOOLING_DIR="/opt/ocs/default/spool/bdb"
PAR_EXECD_INST_COUNT="20"
ADMIN_HOST_LIST="$hostname"
SUBMIT_HOST_LIST="$hostname"
EXEC_HOST_LIST="$hostname"
EXECD_SPOOL_DIR_LOCAL=""
HOSTNAME_RESOLVING="true"
SHELL_NAME="ssh"
COPY_COMMAND="scp"
DEFAULT_DOMAIN="none"
ADMIN_MAIL="none"
ADD_TO_RC="true"
SET_FILE_PERMS="true"
RESCHEDULE_JOBS="wait"
SCHEDD_CONF="3"
SHADOW_HOST=""
EXEC_HOST_LIST_RM=""
REMOVE_RC="false"
CSP_RECREATE="true"
CSP_COPY_CERTS="false"
CSP_COUNTRY_CODE="DE"
CSP_STATE="Germany"
CSP_LOCATION="Building"
CSP_ORGA="Organisation"
CSP_ORGA_UNIT="Organisation_unit"
CSP_MAIL_ADDRESS="name@yourdomain.com"
EOF
}

# Create autoinstall template for execd-only installation
create_execd_template() {
    local hostname="$(hostname)"
    local template_file="$(pwd)/autoinstall.template"
    
    cat > "$template_file" << EOF
SGE_ROOT="/opt/ocs"
SGE_QMASTER_PORT="6444"
SGE_EXECD_PORT="6445"
SGE_ENABLE_SMF="false"
SGE_CLUSTER_NAME="p6444"
CELL_NAME="default"
ADMIN_USER="root"
EXECD_SPOOL_DIR="/opt/ocs/default/spool/execd"
GID_RANGE="20000-20200"
SPOOLING_METHOD="classic"
PAR_EXECD_INST_COUNT="20"
ADMIN_HOST_LIST="$QMASTER_HOSTNAME"
SUBMIT_HOST_LIST="$QMASTER_HOSTNAME"
EXEC_HOST_LIST="$hostname"
EXECD_SPOOL_DIR_LOCAL=""
HOSTNAME_RESOLVING="true"
SHELL_NAME="ssh"
COPY_COMMAND="scp"
DEFAULT_DOMAIN="none"
ADMIN_MAIL="none"
ADD_TO_RC="true"
SET_FILE_PERMS="true"
RESCHEDULE_JOBS="wait"
SCHEDD_CONF="3"
SHADOW_HOST=""
EXEC_HOST_LIST_RM=""
REMOVE_RC="false"
CSP_RECREATE="true"
CSP_COPY_CERTS="false"
CSP_COUNTRY_CODE="DE"
CSP_STATE="Germany"
CSP_LOCATION="Building"
CSP_ORGA="Organisation"
CSP_ORGA_UNIT="Organisation_unit"
CSP_MAIL_ADDRESS="name@yourdomain.com"
EOF
}

# Install Open Cluster Scheduler
install_ocs() {
    echo "Installing Open Cluster Scheduler..."
    export MOUNT_DIR="/opt/ocs"
    export LD_LIBRARY_PATH=""
    local template_file="$(pwd)/autoinstall.template"
    local tmp_template_host="$(pwd)/template_host"
    local current_user="$(whoami)"
    local tmp_config_script="/tmp/ocs_config_$$.sh"
    
    # Check if already installed
    if [ -d ${MOUNT_DIR}/default/common ]; then
        echo "Open Cluster Scheduler seems to be already installed!"
        echo "Starting Open Cluster Scheduler daemons."
        ${MOUNT_DIR}/default/common/sgemaster
        ${MOUNT_DIR}/default/common/sgeexecd
        return 0
    fi
    
    echo "Open Cluster Scheduler is not yet installed in ${MOUNT_DIR}. Starting installation."
    
    # Copy autoinstall template
    sudo cp "$template_file" "${MOUNT_DIR}/"
    
    # Fix filestat issue with Linux namespaces
    cd "${MOUNT_DIR}"
    local sys_arch="$(detect_architecture)"
    sudo rm -f "./utilbin/${sys_arch}/filestat"
    sudo sh -c "echo '#!/bin/sh' > ./utilbin/${sys_arch}/filestat"
    sudo sh -c "echo 'echo root' >> ./utilbin/${sys_arch}/filestat"
    sudo chmod +x "./utilbin/${sys_arch}/filestat"
    
    # Install qmaster and execd
    local hostname="$(hostname)"
    
    # Create template_host in the current directory first, then copy to installation dir
    sed "s:docker:${hostname}:g" "$template_file" > "$tmp_template_host"
    sudo cp "$tmp_template_host" "${MOUNT_DIR}/template_host"
    
    # Run the installation
    cd "${MOUNT_DIR}"
    # On more recent distros the rc directory is missing. Installing rc scripts, switching
    # to systemd later.
    # Rocky 9
    sudo mkdir -p /etc/rc.d/rc3.d/
    # openSUSE Leap 15.6
    sudo mkdir -p /etc/rc.d/init.d/
    sudo ./inst_sge -m -x -auto ./template_host
    
    # Configure environment
    if [ -f "${MOUNT_DIR}/default/common/settings.sh" ]; then
        # Use . instead of source for POSIX compatibility
        . "${MOUNT_DIR}/default/common/settings.sh"
        
        # Create a temporary shell script to run with sudo
        cat > "$tmp_config_script" << EOL
#!/bin/sh
# Source the settings file to set up the environment
. ${MOUNT_DIR}/default/common/settings.sh
# Enable root to submit jobs
qconf -sconf | sed -e 's:100:0:g' > ${MOUNT_DIR}/global
qconf -Mconf ${MOUNT_DIR}/global
# Allow 10 single-core jobs to be processed at once per node
qconf -rattr queue slots 10 all.q
# Make current user a manager
echo "Adding current user (${current_user}) as a manager..."
qconf -am "${current_user}"
# Add settings to root's bashrc
if ! grep -q "${MOUNT_DIR}/default/common/settings.sh" /root/.bashrc; then
    echo ". ${MOUNT_DIR}/default/common/settings.sh" >> /root/.bashrc
fi
EOL

        # Make the script executable
        chmod +x "$tmp_config_script"
        
        # Run the configuration script with sudo
        echo "Running OCS configuration..."
        sudo "$tmp_config_script"
        
        # Add settings to current user's bashrc if not already there
        if ! grep -q "${MOUNT_DIR}/default/common/settings.sh" "$HOME/.bashrc"; then
            {
                echo ""
                echo "# Open Cluster Scheduler settings"
                echo ". ${MOUNT_DIR}/default/common/settings.sh"
            } >> "$HOME/.bashrc"
        fi
        
        # Clean up temporary script
        rm -f "$tmp_config_script"
    else
        echo "ERROR: Installation failed. Could not find settings.sh"
        exit 1
    fi
    
    # Clean up temporary files
    rm -f "$tmp_template_host"
    
    echo "Open Cluster Scheduler $OCS_VERSION installation completed successfully!"
    echo "Current user ($current_user) has been added as a manager"
    echo "Open Cluster Scheduler environment has been added to your ~/.bashrc"
    echo "Please run: source ~/.bashrc or start a new terminal to use Open Cluster Scheduler (qhost, qstat, qsub, ...)"
    
    # Create cluster management structure for execd registrations
    create_cluster_management_structure
}

# Install Open Cluster Scheduler (single-node mode without cluster management)
install_ocs_single() {
    echo "Installing Open Cluster Scheduler (single-node mode)..."
    export MOUNT_DIR="/opt/ocs"
    export LD_LIBRARY_PATH=""
    local template_file="$(pwd)/autoinstall.template"
    local tmp_template_host="$(pwd)/template_host"
    local current_user="$(whoami)"
    local tmp_config_script="/tmp/ocs_config_$$.sh"
    
    # Check if already installed
    if [ -d ${MOUNT_DIR}/default/common ]; then
        echo "Open Cluster Scheduler seems to be already installed!"
        echo "Starting Open Cluster Scheduler daemons."
        ${MOUNT_DIR}/default/common/sgemaster
        ${MOUNT_DIR}/default/common/sgeexecd
        return 0
    fi
    
    echo "Open Cluster Scheduler is not yet installed in ${MOUNT_DIR}. Starting installation."
    
    # Copy autoinstall template
    sudo cp "$template_file" "${MOUNT_DIR}/"
    
    # Fix filestat issue with Linux namespaces
    cd "${MOUNT_DIR}"
    local sys_arch="$(detect_architecture)"
    sudo rm -f "./utilbin/${sys_arch}/filestat"
    sudo sh -c "echo '#!/bin/sh' > ./utilbin/${sys_arch}/filestat"
    sudo sh -c "echo 'echo root' >> ./utilbin/${sys_arch}/filestat"
    sudo chmod +x "./utilbin/${sys_arch}/filestat"
    
    # Install qmaster and execd
    local hostname="$(hostname)"
    
    # Create template_host in the current directory first, then copy to installation dir
    sed "s:docker:${hostname}:g" "$template_file" > "$tmp_template_host"
    sudo cp "$tmp_template_host" "${MOUNT_DIR}/template_host"
    
    # Run the installation
    cd "${MOUNT_DIR}"
    # On more recent distros the rc directory is missing. Installing rc scripts, switching
    # to systemd later.
    # Rocky 9
    sudo mkdir -p /etc/rc.d/rc3.d/
    # openSUSE Leap 15.6
    sudo mkdir -p /etc/rc.d/init.d/
    sudo ./inst_sge -m -x -auto ./template_host
    
    # Configure environment
    if [ -f "${MOUNT_DIR}/default/common/settings.sh" ]; then
        # Use . instead of source for POSIX compatibility
        . "${MOUNT_DIR}/default/common/settings.sh"
        
        # Create a temporary shell script to run with sudo
        cat > "$tmp_config_script" << EOL
#!/bin/sh
# Source the settings file to set up the environment
. ${MOUNT_DIR}/default/common/settings.sh
# Enable root to submit jobs
qconf -sconf | sed -e 's:100:0:g' > ${MOUNT_DIR}/global
qconf -Mconf ${MOUNT_DIR}/global
# Allow 10 single-core jobs to be processed at once per node
qconf -rattr queue slots 10 all.q
# Make current user a manager
echo "Adding current user (${current_user}) as a manager..."
qconf -am "${current_user}"
# Add settings to root's bashrc
if ! grep -q "${MOUNT_DIR}/default/common/settings.sh" /root/.bashrc; then
    echo ". ${MOUNT_DIR}/default/common/settings.sh" >> /root/.bashrc
fi
EOL

        # Make the script executable
        chmod +x "$tmp_config_script"
        
        # Run the configuration script with sudo
        echo "Running OCS configuration..."
        sudo "$tmp_config_script"
        
        # Add settings to current user's bashrc if not already there
        if ! grep -q "${MOUNT_DIR}/default/common/settings.sh" "$HOME/.bashrc"; then
            {
                echo ""
                echo "# Open Cluster Scheduler settings"
                echo ". ${MOUNT_DIR}/default/common/settings.sh"
            } >> "$HOME/.bashrc"
        fi
        
        # Clean up temporary script
        rm -f "$tmp_config_script"
    else
        echo "ERROR: Installation failed. Could not find settings.sh"
        exit 1
    fi
    
    # Clean up temporary files
    rm -f "$tmp_template_host"
    
    echo "Open Cluster Scheduler $OCS_VERSION single-node installation completed successfully!"
    echo "Current user ($current_user) has been added as a manager"
    echo "Open Cluster Scheduler environment has been added to your ~/.bashrc"
    echo "Please run: source ~/.bashrc or start a new terminal to use Open Cluster Scheduler (qhost, qstat, qsub, ...)"
}

# Create cluster management structure and install registration service
create_cluster_management_structure() {
    echo "Setting up cluster management structure..."
    
    local hostname="$(hostname)"
    
    # Create protected directories
    sudo mkdir -p /opt/ocs/.cluster_info
    sudo mkdir -p /opt/ocs/.cluster_management/registration_requests
    sudo mkdir -p /opt/ocs/.cluster_management/registration_approved
    sudo mkdir -p /opt/ocs/.cluster_management/registration_rejected
    
    # Set secure permissions (allow execd nodes to read approvals)
    sudo chmod 755 /opt/ocs/.cluster_management
    sudo chmod 700 /opt/ocs/.cluster_management/registration_requests
    sudo chmod 755 /opt/ocs/.cluster_management/registration_approved  
    sudo chmod 700 /opt/ocs/.cluster_management/registration_rejected
    
    # Write qmaster hostname for execd discovery
    echo "$hostname" | sudo tee /opt/ocs/.cluster_info/qmaster_hostname > /dev/null
    sudo chmod 644 /opt/ocs/.cluster_info/qmaster_hostname
    
    # Write cluster secret for registration validation
    if [ -n "$OCS_CLUSTER_SECRET" ]; then
        printf '%s' "$OCS_CLUSTER_SECRET" | sudo tee /opt/ocs/.cluster_info/cluster_secret > /dev/null
        sudo chmod 600 /opt/ocs/.cluster_info/cluster_secret
    fi
    
    # Create registration processing script
    create_registration_cron_service
    
    # Create installation completion flag
    sudo touch /opt/ocs/.cluster_info/installation_complete
    sudo chmod 644 /opt/ocs/.cluster_info/installation_complete
    
    echo "PASS: Cluster management structure created"
}

# Create background daemon for registration processing (fallback for containers)
create_registration_daemon() {
    echo "Creating background registration daemon..."
    
    # Create daemon script
    sudo tee /opt/ocs/.cluster_management/registration_daemon.sh > /dev/null << 'EOF'
#!/bin/sh
# Background daemon for OCS cluster registration processing
# Fallback when cron is not available (containers, minimal environments)

DAEMON_PID_FILE="/opt/ocs/.cluster_management/registration_daemon.pid"
DAEMON_LOG_FILE="/opt/ocs/.cluster_management/registration_daemon.log"
PROCESS_SCRIPT="/opt/ocs/.cluster_management/process_registrations.sh"

# Signal handlers for clean shutdown
cleanup() {
    echo "$(date): Registration daemon stopping..." >> "$DAEMON_LOG_FILE"
    rm -f "$DAEMON_PID_FILE"
    exit 0
}

trap 'cleanup' TERM INT

# Check if already running
if [ -f "$DAEMON_PID_FILE" ]; then
    if kill -0 "$(cat "$DAEMON_PID_FILE")" 2>/dev/null; then
        echo "Registration daemon already running (PID $(cat "$DAEMON_PID_FILE"))"
        exit 0
    else
        rm -f "$DAEMON_PID_FILE"
    fi
fi

# Write PID file
echo $$ > "$DAEMON_PID_FILE"

# Log startup
echo "$(date): Registration daemon started (PID $$)" >> "$DAEMON_LOG_FILE"

# Main daemon loop
while true; do
    # Run registration processing
    if [ -x "$PROCESS_SCRIPT" ]; then
        "$PROCESS_SCRIPT" >> "$DAEMON_LOG_FILE" 2>&1
    else
        echo "$(date): Registration processing script not found or not executable" >> "$DAEMON_LOG_FILE"
    fi
    
    # Wait 60 seconds (same interval as cron)
    sleep 60
done
EOF
    
    sudo chmod +x /opt/ocs/.cluster_management/registration_daemon.sh
    
    # Start daemon in background
    echo "Starting registration daemon..."
    if (cd /opt/ocs/.cluster_management && sudo nohup ./registration_daemon.sh >/dev/null 2>&1 &); then
        sleep 2  # Give daemon time to start
        if [ -f "/opt/ocs/.cluster_management/registration_daemon.pid" ]; then
            echo "PASS: Registration daemon started (PID $(cat /opt/ocs/.cluster_management/registration_daemon.pid))"
            return 0
        else
            echo "WARNING: Registration daemon may have failed to start"
            return 1
        fi
    else
        echo "WARNING: Failed to start registration daemon"
        return 1
    fi
}

# Attempt to install and start cron service
ensure_cron_service() {
    echo "Checking cron service availability..."
    
    # Check if cron is already running
    if pgrep -x cron >/dev/null 2>&1 || pgrep -x crond >/dev/null 2>&1; then
        echo "PASS: Cron daemon already running"
        return 0
    fi
    
    # Try to install cron if missing
    if ! command -v crontab >/dev/null 2>&1; then
        echo "Attempting to install cron package..."
        if command -v zypper >/dev/null 2>&1; then
            sudo zypper install -y cron >/dev/null 2>&1 || true
        elif command -v yum >/dev/null 2>&1; then
            sudo yum install -y crontabs >/dev/null 2>&1 || true
        elif command -v dnf >/dev/null 2>&1; then
            sudo dnf install -y crontabs >/dev/null 2>&1 || true
        elif command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update >/dev/null 2>&1 && sudo apt-get install -y cron >/dev/null 2>&1 || true
        fi
    fi
    
    # Try multiple methods to start cron daemon
    echo "Attempting to start cron daemon..."
    
    # Method 1: systemctl (modern systems)
    if command -v systemctl >/dev/null 2>&1; then
        if sudo systemctl start cron >/dev/null 2>&1 || sudo systemctl start crond >/dev/null 2>&1; then
            echo "PASS: Cron daemon started via systemctl"
            return 0
        fi
    fi
    
    # Method 2: service command (older systems)
    if command -v service >/dev/null 2>&1; then
        if sudo service cron start >/dev/null 2>&1 || sudo service crond start >/dev/null 2>&1; then
            echo "PASS: Cron daemon started via service"
            return 0
        fi
    fi
    
    # Method 3: Direct execution (containers/minimal environments)
    if command -v crond >/dev/null 2>&1; then
        if sudo crond >/dev/null 2>&1; then
            echo "PASS: Cron daemon started directly"
            return 0
        fi
    elif command -v cron >/dev/null 2>&1; then
        if sudo cron >/dev/null 2>&1; then
            echo "PASS: Cron daemon started directly"
            return 0
        fi
    fi
    
    echo "WARNING: Could not start cron daemon"
    return 1
}

# Create secure service for processing registration requests (cron or daemon)
create_registration_cron_service() {
    echo "Installing registration processing service..."
    
    # Create the registration processing script
    sudo tee /opt/ocs/.cluster_management/process_registrations.sh > /dev/null << 'EOF'
#!/bin/sh
# Secure registration processing service for OCS cluster
source /opt/ocs/default/common/settings.sh

# Portable logging function
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> /opt/ocs/.cluster_management/registration.log
    # Also try logger if available, but don't fail if it's not
    if command -v logger >/dev/null 2>&1; then
        logger "$1"
    fi
}

LOCK_FILE="/opt/ocs/.cluster_management/master_cron.lock"
REQUEST_DIR="/opt/ocs/.cluster_management/registration_requests"
APPROVED_DIR="/opt/ocs/.cluster_management/registration_approved"
REJECTED_DIR="/opt/ocs/.cluster_management/registration_rejected"
CLUSTER_SECRET_FILE="/opt/ocs/.cluster_info/cluster_secret"

# Prevent concurrent execution
if ! (set -C; echo $$ > "$LOCK_FILE") 2>/dev/null; then
    exit 0
fi
trap 'rm -f "$LOCK_FILE"' EXIT

# Source OCS environment if available
if [ -f "/opt/ocs/default/common/settings.sh" ]; then
    . /opt/ocs/default/common/settings.sh
fi

    # Read cluster secret for validation
    if [ -f "$CLUSTER_SECRET_FILE" ]; then
        CLUSTER_SECRET=$(cat "$CLUSTER_SECRET_FILE" | tr -d '\n\r')
    else
        log_message "OCS Registration: No cluster secret found, cannot validate requests"
        exit 1
    fi

# Validate registration request signature
validate_request() {
    local request_file="$1"
    
    # Extract components and strip whitespace
    local message=$(grep "^MESSAGE=" "$request_file" | cut -d'=' -f2- | tr -d '\n\r')
    local signature=$(grep "^SIGNATURE=" "$request_file" | cut -d'=' -f2- | tr -d '\n\r')
    local hostname=$(grep "^HOSTNAME=" "$request_file" | cut -d'=' -f2 | tr -d '\n\r')
    local timestamp=$(grep "^TIMESTAMP=" "$request_file" | cut -d'=' -f2 | tr -d '\n\r')
    
    # Basic validation
    if [ -z "$message" ] || [ -z "$signature" ] || [ -z "$hostname" ] || [ -z "$timestamp" ]; then
        echo "Missing required fields"
        return 1
    fi
    
    # Validate hostname format
    if ! echo "$hostname" | grep -qE '^[a-zA-Z0-9.-]+$'; then
        echo "Invalid hostname format"
        return 1
    fi
    
    # Check if request is too old (24 hours)
    local current_time=$(date +%s)
    if [ $((current_time - timestamp)) -gt 86400 ]; then
        echo "Request expired"
        return 1
    fi
    
    # Verify HMAC signature
    local expected_signature=$(printf '%s' "$message" | openssl dgst -sha256 -hmac "$CLUSTER_SECRET" -binary | base64)
    if [ "$signature" = "$expected_signature" ]; then
        return 0
    else
        # Debug information for signature mismatch
        echo "Invalid signature. Expected: $expected_signature, Got: $signature, Message: $message"
        return 1
    fi
}

# Process registration requests
for request_file in "$REQUEST_DIR"/*; do
    [ -f "$request_file" ] || continue
    
    # Extract hostname for processing
    hostname=$(grep "^HOSTNAME=" "$request_file" | cut -d'=' -f2)
    
    # Validate request
    validation_result=$(validate_request "$request_file")
    if [ $? -ne 0 ]; then
        echo "$validation_result" > "$REJECTED_DIR/$hostname"
        log_message "OCS Registration: Request from $hostname rejected - $validation_result"
        rm -f "$request_file"
        continue
    fi
    
    # Attempt to register admin host
    if qconf -ah "$hostname" 2>/dev/null; then
        echo "Registered successfully at $(date)" > "$APPROVED_DIR/$hostname"
        chmod 644 "$APPROVED_DIR/$hostname"
        log_message "OCS Registration: Admin host $hostname registered successfully"
    else
        error_msg=$(qconf -ah "$hostname" 2>&1)
        echo "Registration failed: $error_msg" > "$REJECTED_DIR/$hostname"
        chmod 644 "$REJECTED_DIR/$hostname"
        log_message "OCS Registration: Admin host $hostname registration failed - $error_msg"
    fi
    
    # Clean up request
    rm -f "$request_file"
done
EOF
    
    # Make script executable
    sudo chmod +x /opt/ocs/.cluster_management/process_registrations.sh
    
    # Setup automatic registration processing
    echo "Setting up periodic registration processing..."
    
    # Debug: Show cron status and ensure cron is running
    echo "DEBUG: Checking cron availability..."
    if command -v crontab >/dev/null 2>&1; then
        echo "DEBUG: crontab command available"
    else
        echo "DEBUG: crontab command NOT available"
    fi
    
    if pgrep -x cron >/dev/null 2>&1; then
        echo "DEBUG: cron process running"
    elif pgrep -x crond >/dev/null 2>&1; then
        echo "DEBUG: crond process running"
    else
        echo "DEBUG: No cron processes detected - attempting to start cron..."
        # Try to start cron proactively
        if command -v cron >/dev/null 2>&1; then
            sudo cron >/dev/null 2>&1 && echo "DEBUG: Started cron daemon" || echo "DEBUG: Failed to start cron"
        elif command -v crond >/dev/null 2>&1; then
            sudo crond >/dev/null 2>&1 && echo "DEBUG: Started crond daemon" || echo "DEBUG: Failed to start crond"
        fi
    fi
    
    # Try cron first - simple and direct approach
    if command -v crontab >/dev/null 2>&1 && (pgrep -x cron >/dev/null 2>&1 || pgrep -x crond >/dev/null 2>&1); then
        echo "Installing cron job for registration processing..."
        if (sudo crontab -l 2>/dev/null | grep -v "process_registrations.sh"; echo "* * * * * /opt/ocs/.cluster_management/process_registrations.sh") | sudo crontab -; then
            echo "PASS: Registration processing via crontab (every minute)"
            # Verify installation
            if sudo crontab -l | grep -q "process_registrations.sh"; then
                echo "VERIFIED: Cron job successfully installed"
                return 0
            else
                echo "WARNING: Cron job installation may have failed, trying fallback..."
            fi
        else
            echo "WARNING: Failed to install cron job, trying alternative methods..."
        fi
    fi
    
    # If cron not available, ensure it's started and try again  
    echo "Cron not ready, attempting to start cron service..."
    if ensure_cron_service; then
        if command -v crontab >/dev/null 2>&1; then
            echo "Retry: Installing cron job after starting cron service..."
            if (sudo crontab -l 2>/dev/null | grep -v "process_registrations.sh"; echo "* * * * * /opt/ocs/.cluster_management/process_registrations.sh") | sudo crontab -; then
                echo "PASS: Registration processing via crontab (every minute)"
                # Verify installation
                if sudo crontab -l | grep -q "process_registrations.sh"; then
                    echo "VERIFIED: Cron job successfully installed on retry"
                    return 0
                else
                    echo "WARNING: Cron job installation failed on retry"
                fi
            else
                echo "WARNING: Failed to install cron job on retry"
            fi
        fi
    fi
    
    # Fallback to background daemon
    echo "Cron unavailable, setting up background daemon..."
    if create_registration_daemon; then
        echo "PASS: Registration processing via background daemon"
        return 0
    fi
    
    # Final fallback - graceful degradation
    echo "WARNING: Could not set up automatic registration processing"
    echo "Cluster node registration will require manual intervention using:"
    echo "  sudo /opt/ocs/.cluster_management/process_registrations.sh"
    return 1
}

# Install Open Cluster Scheduler execd only using shared filesystem
install_execd_only() {
    echo "Installing Open Cluster Scheduler execd only..."
    export MOUNT_DIR="/opt/ocs"
    export LD_LIBRARY_PATH=""
    local template_file="$(pwd)/autoinstall.template"
    local tmp_template_host="$(pwd)/template_host"
    local current_user="$(whoami)"
    
    # Wait for master installation to complete
    wait_for_master_installation
    
    # Register this host as admin host
    register_admin_host
    
    # Check if OCS binaries are available from shared filesystem
    if [ ! -d "${MOUNT_DIR}/default/common" ]; then
        echo "ERROR: OCS installation not found in shared filesystem at ${MOUNT_DIR}"
        echo "Ensure master installation completed successfully and filesystem is shared"
        exit 1
    fi
    
    # Check if the correct architecture binaries are available
    local execd_arch="$(detect_architecture)"
    echo "Execd architecture detected: $execd_arch"
    
    # Check what architecture is installed in the shared filesystem
    local installed_archs=""
    for arch_dir in "${MOUNT_DIR}/bin/"*; do
        if [ -d "$arch_dir" ]; then
            local arch_name="$(basename "$arch_dir")"
            installed_archs="$installed_archs $arch_name"
        fi
    done
    
    echo "Available architectures in shared filesystem:$installed_archs"
    
    # Check if our architecture is available
    if [ -d "${MOUNT_DIR}/bin/${execd_arch}" ]; then
        echo "Compatible binaries found for $execd_arch, using shared filesystem installation"
    else
        echo "WARNING: No $execd_arch binaries found in shared filesystem"
        echo "Available architectures:$installed_archs"
        echo "Downloading $execd_arch binaries for this execd node..."
        
        # Download architecture-specific binaries for this execd
        if ! download_execd_binaries "$execd_arch"; then
            # If primary architecture fails and we're on CentOS 7, try lx-amd64 fallback
            if [ "$execd_arch" = "ulx-amd64" ]; then
                echo "WARNING: $execd_arch download failed, trying lx-amd64 fallback for compatibility..."
                if download_execd_binaries "lx-amd64"; then
                    echo "Successfully fell back to lx-amd64 binaries"
                    execd_arch="lx-amd64"  # Update architecture for subsequent operations
                else
                    echo "ERROR: Both $execd_arch and lx-amd64 fallback failed"
                    exit 1
                fi
            else
                echo "ERROR: Failed to download $execd_arch binaries and no fallback available"
                exit 1
            fi
        fi
    fi
    
    # Check if execd is already configured on this host
    if [ -f "${MOUNT_DIR}/default/spool/execd/$(hostname)/active_jobs" ] || \
       [ -d "${MOUNT_DIR}/default/spool/execd/$(hostname)" ]; then
        echo "Execd appears to already be configured for this host"
        echo "Starting Open Cluster Scheduler execd daemon."
        ${MOUNT_DIR}/default/common/sgeexecd
        return 0
    fi
    
    echo "Configuring execd for this host..."
    
    # Create local working directory for configuration
    local work_dir="/tmp/ocs_execd_config_$$"
    mkdir -p "$work_dir"
    cd "$work_dir"
    
    # Copy template to working directory
    cp "$template_file" .
    
    # Install execd only (no qmaster, no file downloads needed)
    local hostname="$(hostname)"
    local unique_template="template_host_${hostname}_$$"
    
    # Create unique template_host to avoid conflicts with parallel execd installations
    sed "s:docker:${hostname}:g" autoinstall.template > "$unique_template"
    
    # Copy template to installation directory with unique name
    sudo cp "$unique_template" "${MOUNT_DIR}/$unique_template"
    
    # Change to installation directory
    cd "${MOUNT_DIR}"
    
    # On more recent distros the rc directory is missing
    sudo mkdir -p /etc/rc.d/rc3.d/
    sudo mkdir -p /etc/rc.d/init.d/
    
    # Run execd installation (no -m flag for qmaster)
    echo "Running OCS execd installation..."
    sudo ./inst_sge -x -auto ./"$unique_template"
    
    # Configure environment (skip qmaster-specific configuration)
    if [ -f "${MOUNT_DIR}/default/common/settings.sh" ]; then
        # Add settings to current user's bashrc if not already there
        if ! grep -q "${MOUNT_DIR}/default/common/settings.sh" "$HOME/.bashrc"; then
            {
                echo ""
                echo "# Open Cluster Scheduler settings"
                echo ". ${MOUNT_DIR}/default/common/settings.sh"
            } >> "$HOME/.bashrc"
        fi
    else
        echo "ERROR: Installation failed. Could not find settings.sh"
        exit 1
    fi
    
    # Clean up temporary files
    cd /
    rm -rf "$work_dir"
    sudo rm -f "${MOUNT_DIR}/$unique_template"
    
    echo "Open Cluster Scheduler $OCS_VERSION execd installation completed successfully!"
    echo "Execd has been configured to connect to qmaster: $QMASTER_HOSTNAME"
    echo "Open Cluster Scheduler environment has been added to your ~/.bashrc"
    echo "Please run: source ~/.bashrc or start a new terminal to use Open Cluster Scheduler commands"
}

# Main execution
main() {
    # Display version information
    echo "================================"
    echo "Open Cluster Scheduler Installer"
    echo "Version to install: $OCS_VERSION"
    echo "Install mode: $OCS_INSTALL_MODE"
    echo "================================"
    echo ""
    
    # Validate version before proceeding
    case "$OCS_VERSION" in
        "9.0.5"|"9.0.6"|"9.0.7")
            # Supported versions
            ;;
        "9.0.8")
            echo "WARNING: Version 9.0.8 URLs are not yet available."
            echo "Please update the script with actual URLs when they become available."
            exit 1
            ;;
        *)
            echo "ERROR: Unsupported version: $OCS_VERSION"
            echo "Supported versions: 9.0.5, 9.0.6, 9.0.7"
            echo "Usage: OCS_VERSION=9.0.6 $0"
            exit 1
            ;;
    esac
    
    # Validate install mode and execute appropriate installation
    case "$OCS_INSTALL_MODE" in
        "full")
            echo "Performing full OCS installation (qmaster + execd + simple cluster management)..."
            
            # For full installation, generate cluster secret if not provided
            if [ -z "$OCS_CLUSTER_SECRET" ]; then
                # Check if openssl is available for key generation
                if ! command -v openssl >/dev/null 2>&1; then
                    echo "ERROR: openssl command not found, required for cluster secret generation"
                    echo "Please install openssl package or provide OCS_CLUSTER_SECRET manually"
                    exit 1
                fi
                echo "Generating cluster secret for secure execd registration..."
                OCS_CLUSTER_SECRET=$(openssl rand -hex 32)
                echo "Generated cluster secret: $OCS_CLUSTER_SECRET"
                echo "Use this secret for execd installations: OCS_CLUSTER_SECRET=$OCS_CLUSTER_SECRET"
            fi
            
            install_packages
            setup_directories
            download_files
            create_autoinstall_template
            install_ocs
            ;;
        "single")
            echo "Performing single-node OCS installation (qmaster + execd, no cluster management)..."
            install_packages
            setup_directories
            download_files
            create_autoinstall_template
            install_ocs_single
            ;;
        "execd")
            echo "Performing execd-only installation using shared filesystem..."
            validate_execd_basic_prerequisites
            install_packages
            validate_execd_advanced_prerequisites
            create_execd_template
            install_execd_only
            ;;
        *)
            echo "ERROR: Invalid OCS_INSTALL_MODE: $OCS_INSTALL_MODE"
            echo "Supported modes: full, single, execd"
            echo "Usage examples:"
            echo "  Single-node: $0  (or OCS_INSTALL_MODE=single $0)"
            echo "  Full cluster: OCS_CLUSTER_SECRET=your-hex-key $0"
            echo "  Execd installation: OCS_INSTALL_MODE=execd OCS_CLUSTER_SECRET=your-hex-key $0"
            exit 1
            ;;
    esac
}

# Run the script
main

exit 0
