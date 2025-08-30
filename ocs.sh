#!/bin/sh
#
# Improved Open Cluster Scheduler Installation Script
# Works across Linux distributions
# 
# Usage:
#   curl -s <script_url> | sh                    # Installs default version
#   curl -s <script_url> | OCS_VERSION=9.0.6 sh  # Installs specific version
#

set -e  # Exit on error
#set -u  # Treat unset variables as errors

# Default version - can be overridden by environment variable
OCS_VERSION="${OCS_VERSION:-9.0.8}"

echo "Starting Open Cluster Scheduler installation (version: $OCS_VERSION)..."

# Function to get download URLs based on version
get_download_urls() {
    local version="$1"
    local arch="$2"  # lx-amd64, lx-arm64, ulx-amd64
    
    case "$version" in
        "9.0.5")
            case "$arch" in
                "lx-amd64")
                    echo "https://www.hpc-gridware.com/download/10529/?tmstv=1745334305"
                    ;;
                "ulx-amd64")
                    echo "https://www.hpc-gridware.com/download/10535/?tmstv=1745334305"
                    ;;
                "doc")
                    echo "https://www.hpc-gridware.com/download/10543/?tmstv=1745334305"
                    ;;
                "common")
                    echo "https://www.hpc-gridware.com/download/10541/?tmstv=1745334305"
                    ;;
                *)
                    echo ""
                    ;;
            esac
            ;;
        "9.0.6")
            case "$arch" in
                "lx-amd64")
                    echo "https://www.hpc-gridware.com/download/10646/?tmstv=1749092703"
                    ;;
                "lx-arm64")
                    echo "https://www.hpc-gridware.com/download/10648/?tmstv=1749092703"
                    ;;
                "ulx-amd64")
                    echo "https://www.hpc-gridware.com/download/10652/?tmstv=1749092703"
                    ;;
                "doc")
                    echo "https://www.hpc-gridware.com/download/10656/?tmstv=1749092703"
                    ;;
                "common")
                    echo "https://www.hpc-gridware.com/download/10654/?tmstv=1749092703"
                    ;;
                *)
                    echo ""
                    ;;
            esac
            ;;
        "9.0.7")
            case "$arch" in
                "lx-amd64")
                    echo "https://www.hpc-gridware.com/download/10802/?tmstv=1751900704"
                    ;;
                "lx-arm64")
                    echo "https://www.hpc-gridware.com/download/10804/?tmstv=1751900704"
                    ;;
                "ulx-amd64")
                    echo "https://www.hpc-gridware.com/download/10808/?tmstv=1751900704"
                    ;;
                "doc")
                    echo "https://www.hpc-gridware.com/download/10818/?tmstv=1751900704"
                    ;;
                "common")
                    echo "https://www.hpc-gridware.com/download/10816/?tmstv=1751900704"
                    ;;
                *)
                    echo ""
                    ;;
            esac
            ;;
        "9.0.8")
            case "$arch" in
                "lx-amd64")
                    echo "https://www.hpc-gridware.com/download/11126/?tmstv=1756559953"
                    ;;
                "lx-arm64")
                    echo "https://www.hpc-gridware.com/download/11128/?tmstv=1756559954"
                    ;;
                "ulx-amd64")
                    echo "https://www.hpc-gridware.com/download/11132/?tmstv=1756559954"
                    ;;
                "doc")
                    echo "https://www.hpc-gridware.com/download/11140/?tmstv=1756559954"
                    ;;
                "common")
                    echo "https://www.hpc-gridware.com/download/11138/?tmstv=1756559954"
                    ;;
                *)
                    echo ""
                    ;;
            esac
            ;;
        *)
            echo "ERROR: Unsupported OCS version: $version" >&2
            echo "Supported versions: 9.0.5, 9.0.6, 9.0.7, 9.0.8" >&2
            exit 1
            ;;
    esac
}

# Function to detect system architecture
detect_architecture() {
    local arch=$(uname -m)
    local os_release=""
    
    # Check if it's an old Linux system (like CentOS 7)
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [ "$ID" = "centos" ] && [ "${VERSION_ID%%.*}" -le 7 ]; then
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

# Function to install packages based on the package manager
install_packages() {
    local packages="git tar binutils sudo make wget bash"
    local epel_installed=0
    
    if command -v apt &> /dev/null; then
        echo "Detected apt package manager"
        sudo apt update
        sudo apt install -y $packages
        
        # On Ubuntu, the package names are libtirpc3 and libtirpc-dev
        echo "Installing libtirpc packages..."
        sudo apt install -y libtirpc3 libtirpc-dev
    elif command -v dnf &> /dev/null; then
        echo "Detected dnf package manager"
        
        # First install dnf-plugins-core if not already installed
        if ! rpm -q dnf-plugins-core &> /dev/null; then
            echo "Installing dnf-plugins-core for repository management..."
            sudo dnf install -y dnf-plugins-core
        fi
        
        # Try to install packages directly first
        sudo dnf install -y $packages
        
        echo "Enabling CRB/CodeReady repo for development packages..."
        source /etc/os-release
        if [ "${ID}" = "ol" ] && [[ "${VERSION_ID}" == 9* ]]; then
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
    elif command -v yum &> /dev/null; then
        echo "Detected yum package manager"
        sudo yum install -y $packages
        
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
    elif command -v pacman &> /dev/null; then
        echo "Detected pacman package manager"
        sudo pacman -Sy --noconfirm $packages screen libtirpc
    elif command -v zypper &> /dev/null; then
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
        packages="git tar binutils sudo make wget bash screen libtirpc libtirpc-devel"

        if [ "$DISTID" = "sles" ]; then
          echo "Detected SUSE Linux Enterprise Server $DISTVERSION"
          # Register Desktop Applications module FIRST
          sudo SUSEConnect -p sle-module-desktop-applications/${VERSION_ID}/x86_64 || \
            sudo SUSEConnect -p sle-module-desktop-applications/15/x86_64
          # Register Development Tools module
          sudo SUSEConnect -p sle-module-development-tools/${VERSION_ID}/x86_64 || \
            sudo SUSEConnect -p sle-module-development-tools/15/x86_64
          packages="git-core tar binutils sudo make wget bash screen libtirpc3 libtirpc-devel"
        elif [ "$DISTID" = "opensuse-leap" ]; then
          echo "Detected openSUSE Leap $DISTVERSION"
          # On openSUSE, package names are as expected
          packages="git tar binutils sudo make wget bash screen libtirpc3 libtirpc-devel"
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
        if ! command -v git &>/dev/null; then
          echo "ERROR: git could not be installed."
          exit 1
        fi
    else
        echo "ERROR: Unsupported package manager. Please install the following packages manually:"
        echo "$packages screen libtirpc libtirpc-devel"
        exit 1
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
    local sys_arch=$(detect_architecture)
    echo "Detected system architecture: $sys_arch"
    
    # Use the local directory for downloads
    local download_dir="./ocs_downloads"
    
    # Clean up existing downloads
    echo "Cleaning up existing downloads..."
    rm -rf "$download_dir"
    mkdir -p "$download_dir"
    
    cd "$download_dir"
    
    # Download architecture-specific binary package
    local bin_url=$(get_download_urls "$OCS_VERSION" "$sys_arch")
    if [ -n "$bin_url" ] && [ "$bin_url" != "https://www.hpc-gridware.com/download/XXXXX/?tmstv=XXXXXXXXXX" ]; then
        echo "Downloading $sys_arch binary package..."
        wget -q --show-progress -k --content-disposition "$bin_url"
    else
        echo "ERROR: No valid URL for $sys_arch binary package for version $OCS_VERSION"
        exit 1
    fi
    
    # For ARM64 systems with version 9.0.6+, also check if lx-arm64 is available
    if [ "$sys_arch" = "lx-amd64" ] && [ "$OCS_VERSION" != "9.0.5" ]; then
        local arm64_url=$(get_download_urls "$OCS_VERSION" "lx-arm64")
        if [ -n "$arm64_url" ] && [ "$arm64_url" != "https://www.hpc-gridware.com/download/XXXXX/?tmstv=XXXXXXXXXX" ]; then
            echo "Note: ARM64 binary is also available for this version"
        fi
    fi
    
    # Download common packages
    for pkg in "doc" "common"; do
        local url=$(get_download_urls "$OCS_VERSION" "$pkg")
        if [ -n "$url" ] && [ "$url" != "https://www.hpc-gridware.com/download/XXXXX/?tmstv=XXXXXXXXXX" ]; then
            echo "Downloading $pkg package..."
            wget -q --show-progress -k --content-disposition "$url"
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

# Create autoinstall template
create_autoinstall_template() {
    local hostname=$(hostname)
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

# Install Open Cluster Scheduler
install_ocs() {
    echo "Installing Open Cluster Scheduler..."
    export MOUNT_DIR="/opt/ocs"
    export LD_LIBRARY_PATH=""
    local template_file="$(pwd)/autoinstall.template"
    local tmp_template_host="$(pwd)/template_host"
    local current_user=$(whoami)
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
    sudo rm -f ./utilbin/lx-amd64/filestat
    sudo sh -c 'echo "#!/bin/sh" > ./utilbin/lx-amd64/filestat'
    sudo sh -c 'echo "echo root" >> ./utilbin/lx-amd64/filestat'
    sudo chmod +x ./utilbin/lx-amd64/filestat
    
    # Install qmaster and execd
    local hostname=$(hostname)
    
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
            echo "" >> "$HOME/.bashrc"
            echo "# Open Cluster Scheduler settings" >> "$HOME/.bashrc"
            echo ". ${MOUNT_DIR}/default/common/settings.sh" >> "$HOME/.bashrc"
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
}

# Main execution
main() {
    # Display version information
    echo "================================"
    echo "Open Cluster Scheduler Installer"
    echo "Version to install: $OCS_VERSION"
    echo "================================"
    echo ""
    
    # Validate version before proceeding
    case "$OCS_VERSION" in
        "9.0.5"|"9.0.6"|"9.0.7"|"9.0.8")
            # Supported versions
            ;;
        *)
            echo "ERROR: Unsupported version: $OCS_VERSION"
            echo "Supported versions: 9.0.5, 9.0.6, 9.0.7, 9.0.8"
            echo "Usage: OCS_VERSION=9.0.6 $0"
            exit 1
            ;;
    esac
    
    install_packages
    setup_directories
    download_files
    create_autoinstall_template
    install_ocs
}

# Run the script
main

exit 0
