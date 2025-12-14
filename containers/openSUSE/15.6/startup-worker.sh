#!/bin/bash
# Copyright (C) 2024 Gridware GmbH
# Startup script for OCS worker nodes

set -e

echo "=================================================="
echo "OCS Worker Node Startup: $(hostname)"
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

# Source OCS environment
. /opt/ocs/default/common/settings.sh

# Wait a bit more for master daemons to be fully ready
echo "Waiting for master daemons to be ready..."
sleep 10

# Start execd daemon on this worker
echo "Starting execd daemon on $(hostname)..."
/opt/ocs/default/common/sgeexecd start

# Wait to ensure execd is running
sleep 3

# Verify execd started
if pgrep -x sge_execd > /dev/null; then
    echo "Execd daemon started successfully"
else
    echo "WARNING: Execd daemon may not have started correctly"
fi

# Add OCS settings to gridware user's bashrc
if ! grep -q "/opt/ocs/default/common/settings.sh" /home/gridware/.bashrc 2>/dev/null; then
    echo "" >> /home/gridware/.bashrc
    echo "# Open Cluster Scheduler settings" >> /home/gridware/.bashrc
    echo ". /opt/ocs/default/common/settings.sh" >> /home/gridware/.bashrc
    echo "Added OCS settings to gridware user's bashrc"
fi

echo "=================================================="
echo "Worker node $(hostname) ready and joined cluster."
echo "=================================================="

# Execute the command passed to the container
exec "$@"
