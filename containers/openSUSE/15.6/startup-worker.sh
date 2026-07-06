#!/bin/bash
# Copyright (C) 2024 Gridware GmbH
# Startup script for OCS worker nodes

set -e

echo "=================================================="
echo "OCS Worker Node Startup: $(hostname)"
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

# Wait for master node to complete installation
echo "Waiting for master node to complete OCS installation..."
MAX_WAIT=300
ELAPSED=0
while [ ! -f "/opt/ocs/default/common/settings.sh" ] && [ $ELAPSED -lt $MAX_WAIT ]; do
    sleep 5
    ELAPSED=$((ELAPSED + 5))
    echo "Waiting for master installation... (${ELAPSED}s/${MAX_WAIT}s)"
done

if [ ! -f "/opt/ocs/default/common/settings.sh" ]; then
    echo "ERROR: Master installation did not complete within ${MAX_WAIT} seconds"
    exit 1
fi

echo "Master installation detected. Configuring worker node..."

# Accept newer Linux kernels in the arch detection script of an existing
# installation. Upstream only whitelists kernels up to 6.*; newer kernels
# (e.g. 7.x used by OrbStack) are reported as UNSUPPORTED-* and daemon
# startup fails with "can't determine path to Cluster Scheduler utility
# binaries". Idempotent: the pattern no longer matches once replaced.
if [ -f /opt/ocs/util/arch ]; then
    sed -i 's/2\.4\.\*|2\.6\.\*|3\.\*|4\.\*|5\.\*|6\.\*)/2.4.*|2.6.*|[3-9].*)/' /opt/ocs/util/arch
fi

# Source OCS environment
. /opt/ocs/default/common/settings.sh

# Wait a bit more for master daemons to be fully ready
echo "Waiting for master daemons to be ready..."
sleep 10

# Start execd daemon on this worker (skip if already running)
if pgrep -x sge_execd > /dev/null; then
    echo "execd daemon is already running."
else
    echo "Starting execd daemon on $(hostname)..."
    /opt/ocs/default/common/sgeexecd start
fi

# Wait to ensure execd is running
sleep 3

# Verify execd started
if pgrep -x sge_execd > /dev/null; then
    echo "Execd daemon started successfully"
else
    echo "WARNING: Execd daemon may not have started correctly"
fi

# Add OCS settings to bashrc for root and gridware user
for bashrc in /root/.bashrc /home/gridware/.bashrc; do
    if ! grep -q "/opt/ocs/default/common/settings.sh" "$bashrc" 2>/dev/null; then
        echo "" >> "$bashrc"
        echo "# Open Cluster Scheduler settings" >> "$bashrc"
        echo ". /opt/ocs/default/common/settings.sh" >> "$bashrc"
    fi
done

echo "=================================================="
echo "Worker node $(hostname) ready and joined cluster."
echo "=================================================="

# Execute the command passed to the container
exec "$@"
