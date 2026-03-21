#!/bin/bash
# Copyright (C) 2024 Gridware GmbH
# Startup script for OCS master node

set -e

echo "=================================================="
echo "OCS Master Node Startup"
echo "=================================================="

# Configure /etc/hosts with all cluster nodes
echo "Configuring /etc/hosts with cluster nodes..."
cat >> /etc/hosts << EOF
10.100.0.10 ocs-master
10.100.0.11 ocs-worker1
10.100.0.12 ocs-worker2
EOF

# Display configured hosts
echo "Cluster nodes configured:"
grep "^10.100.0" /etc/hosts

# Wait a moment for network to be ready
sleep 2

# Check if OCS is already installed
if [ -d "/opt/ocs/default/common" ]; then
    echo "Open Cluster Scheduler is already installed."
    echo "Starting OCS daemons..."

    # Source OCS environment
    if [ -f "/opt/ocs/default/common/settings.sh" ]; then
        . /opt/ocs/default/common/settings.sh

        # Start master daemon
        echo "Starting qmaster daemon..."
        /opt/ocs/default/common/sgemaster start

        # Start execd daemon on master
        echo "Starting execd daemon on master..."
        /opt/ocs/default/common/sgeexecd start

        echo "OCS daemons started successfully."
    else
        echo "ERROR: OCS settings.sh not found!"
        exit 1
    fi
else
    echo "OCS not installed. Starting installation..."
    echo "Installation will configure cluster with:"
    echo "  Master: ${OCS_MASTER_HOST}"
    echo "  Execution hosts: ${OCS_EXEC_HOSTS}"

    # Set environment variables for multi-node installation
    export OCS_VERSION="${OCS_VERSION:-9.0.11}"
    export OCS_EXEC_HOSTS="${OCS_EXEC_HOSTS:-ocs-master}"
    export OCS_ADMIN_HOSTS="${OCS_ADMIN_HOSTS:-${OCS_EXEC_HOSTS}}"
    export OCS_SUBMIT_HOSTS="${OCS_SUBMIT_HOSTS:-${OCS_EXEC_HOSTS}}"

    # Copy installation script to writable location
    cp /tmp/ocs.sh /root/ocs.sh
    chmod +x /root/ocs.sh

    # Run installation script
    cd /root
    /root/ocs.sh

    echo "OCS installation completed on master node."

    # Configure worker nodes in the cluster
    echo "Configuring execution hosts in cluster..."
    . /opt/ocs/default/common/settings.sh

    # Add all execution hosts (from OCS_EXEC_HOSTS) to the cluster
    for host in $OCS_EXEC_HOSTS; do
        if [ "$host" != "ocs-master" ]; then
            echo "Adding $host to cluster configuration..."

            # Add as admin host
            qconf -ah "$host" 2>/dev/null || echo "$host already in admin host list"

            # Add as submit host
            qconf -as "$host" 2>/dev/null || echo "$host already in submit host list"

            # Add to @allhosts hostgroup
            qconf -aattr hostgroup hostlist "$host" @allhosts 2>/dev/null || echo "$host already in @allhosts"
        fi
    done

    echo "Cluster configuration complete."
fi

# Add OCS settings to bashrc for root and gridware user
if [ -f "/opt/ocs/default/common/settings.sh" ]; then
    for bashrc in /root/.bashrc /home/gridware/.bashrc; do
        if ! grep -q "/opt/ocs/default/common/settings.sh" "$bashrc" 2>/dev/null; then
            echo "" >> "$bashrc"
            echo "# Open Cluster Scheduler settings" >> "$bashrc"
            echo ". /opt/ocs/default/common/settings.sh" >> "$bashrc"
        fi
    done
fi

echo "=================================================="
echo "Master node ready. Cluster information:"
. /opt/ocs/default/common/settings.sh
qconf -sh 2>/dev/null || echo "Waiting for qmaster to be fully ready..."
echo "=================================================="

# Execute the command passed to the container
exec "$@"
