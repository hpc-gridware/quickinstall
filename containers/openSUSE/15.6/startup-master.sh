#!/bin/bash
# Copyright (C) 2024 Gridware GmbH
# Startup script for OCS master node

set -e

echo "=================================================="
echo "OCS Master Node Startup"
echo "=================================================="

# Fix ownership of bind-mounted home dir for gridware (uid 1000).
# Required on Linux hosts where bind mounts retain host UIDs; on macOS
# Docker Desktop maps UIDs transparently and this is a no-op.
chown -R gridware:gridware /home/gridware

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

# Start SSH daemon
echo "Starting SSH daemon..."
ssh-keygen -A
if ! pgrep -x sshd > /dev/null; then
    /usr/sbin/sshd
fi

# Set up passwordless SSH for gridware. /home/gridware is shared between
# all nodes, so one keypair in ~/.ssh works cluster-wide; only the master
# generates it, the workers pick it up via the shared home.
SSH_DIR=/home/gridware/.ssh
if [ ! -f "$SSH_DIR/id_ed25519" ]; then
    echo "Generating SSH keypair for gridware user..."
    mkdir -p "$SSH_DIR"
    ssh-keygen -t ed25519 -N "" -f "$SSH_DIR/id_ed25519"
    cat "$SSH_DIR/id_ed25519.pub" >> "$SSH_DIR/authorized_keys"
    chmod 700 "$SSH_DIR"
    chmod 600 "$SSH_DIR/authorized_keys" "$SSH_DIR/id_ed25519"
    chown -R gridware:gridware "$SSH_DIR"
fi

# Wait a moment for network to be ready
sleep 2

# Accept newer Linux kernels in the arch detection script of an existing
# installation. Upstream only whitelists kernels up to 6.*; newer kernels
# (e.g. 7.x used by OrbStack) are reported as UNSUPPORTED-* and daemon
# startup fails with "can't determine path to Cluster Scheduler utility
# binaries". Idempotent: the pattern no longer matches once replaced.
if [ -f /opt/ocs/util/arch ]; then
    sed -i 's/2\.4\.\*|2\.6\.\*|3\.\*|4\.\*|5\.\*|6\.\*)/2.4.*|2.6.*|[3-9].*)/' /opt/ocs/util/arch
fi

# Check if OCS is already installed
if [ -d "/opt/ocs/default/common" ]; then
    echo "Open Cluster Scheduler is already installed."
    echo "Starting OCS daemons..."

    # Source OCS environment
    if [ -f "/opt/ocs/default/common/settings.sh" ]; then
        . /opt/ocs/default/common/settings.sh

        # Start master daemon (skip if already running, e.g. container restart)
        if pgrep -x sge_qmaster > /dev/null; then
            echo "qmaster daemon is already running."
        else
            echo "Starting qmaster daemon..."
            /opt/ocs/default/common/sgemaster start
        fi

        # Start execd daemon on master
        if pgrep -x sge_execd > /dev/null; then
            echo "execd daemon is already running."
        else
            echo "Starting execd daemon on master..."
            /opt/ocs/default/common/sgeexecd start
        fi

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
    export OCS_VERSION="${OCS_VERSION:-9.1.3}"
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
