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

# The bind mount hides the .bashrc that the image put into /home/gridware, so
# write it again here. Done before the installation so that the OCS environment
# is in place even if the installation fails or is still running.
if ! grep -q "/etc/profile.d/ocs.sh" /home/gridware/.bashrc 2>/dev/null; then
    cat /etc/ocs-bashrc.snippet >> /home/gridware/.bashrc
fi
chown gridware:gridware /home/gridware/.bashrc

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

# Nodes that form the cluster. Used for the admin and submit host lists only:
# every node installs and registers its own execd, so nothing here triggers a
# remote installation. Defaults to this host, which is the single-node case.
CLUSTER_HOSTS="${OCS_EXEC_HOSTS:-$(hostname)}"

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
    echo "  Cluster hosts: ${CLUSTER_HOSTS}"

    # Set environment variables for multi-node installation. OCS_VERSION is
    # passed through as it is; ocs.sh defaults to the latest supported version.
    export OCS_ADMIN_HOSTS="${OCS_ADMIN_HOSTS:-${CLUSTER_HOSTS}}"
    export OCS_SUBMIT_HOSTS="${OCS_SUBMIT_HOSTS:-${CLUSTER_HOSTS}}"

    # Install the execd of this node only. Every additional host in
    # EXEC_HOST_LIST makes the auto installer ssh into that node as root to
    # install its execd remotely. root has no key in this image, so the ssh
    # blocks on the password prompt forever and the installation never
    # finishes. The workers install and register their own execd instead, see
    # startup-worker.sh. For a single-node setup this is the full list anyway.
    OCS_EXEC_HOSTS="$(hostname)"
    export OCS_EXEC_HOSTS

    # Copy installation script to writable location
    cp /tmp/ocs.sh /root/ocs.sh
    chmod +x /root/ocs.sh

    # Run installation script
    cd /root
    /root/ocs.sh

    echo "OCS installation completed on master node."
fi

. /opt/ocs/default/common/settings.sh

# Let every cluster node talk to the qmaster. The installation already did this
# for the hosts it knew about; repeating it on every start picks up nodes added
# to OCS_EXEC_HOSTS later and is a no-op otherwise. A worker has to be an admin
# host before it can register its execd and create its queue instance.
echo "Checking admin and submit host lists..."
for host in $CLUSTER_HOSTS; do
    qconf -sh | grep -qx "$host" || qconf -ah "$host" ||
        echo "WARNING: cannot add $host as admin host"
    qconf -ss | grep -qx "$host" || qconf -as "$host" ||
        echo "WARNING: cannot add $host as submit host"
done

echo "=================================================="
echo "Master node ready. Cluster information:"
qconf -sh 2>/dev/null || echo "Waiting for qmaster to be fully ready..."
echo "=================================================="

# Execute the command passed to the container
exec "$@"
