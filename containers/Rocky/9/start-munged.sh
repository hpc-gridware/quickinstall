#!/bin/bash
# Copyright (C) 2026 Gridware GmbH
# Start munged on a cluster node (installed as /usr/local/sbin/start-munged).
#
# Used by the startup scripts when the OCS installation runs with MUNGE
# authentication (security_mode munge in the bootstrap file). The key is
# created by the master on first start (ocs.sh) in the munge-key volume that
# is mounted at /etc/munge on all nodes, so a worker may have to wait for it.
# Systemd is not PID 1 in the containers, so munged is started directly.

KEY_FILE=/etc/munge/munge.key
MAX_WAIT=60

munge_is_running() {
    munge -n 2>/dev/null | unmunge >/dev/null 2>&1
}

if munge_is_running; then
    echo "munged is already running."
    exit 0
fi

ELAPSED=0
while [ ! -f "$KEY_FILE" ] && [ $ELAPSED -lt $MAX_WAIT ]; do
    echo "Waiting for the MUNGE key $KEY_FILE... (${ELAPSED}s/${MAX_WAIT}s)"
    sleep 2
    ELAPSED=$((ELAPSED + 2))
done

if [ ! -f "$KEY_FILE" ]; then
    echo "ERROR: MUNGE key $KEY_FILE not found. The master creates it in the"
    echo "       munge-key volume on the first start of the cluster. If that volume"
    echo "       was removed, recreate the cluster: docker compose down -v"
    exit 1
fi

echo "Starting munged..."
# tmpfiles does not run in a container, so /run/munge may be missing.
mkdir -p /run/munge
chown munge:munge /run/munge
chmod 755 /run/munge
runuser -u munge -- /usr/sbin/munged || true

if ! munge_is_running; then
    echo "ERROR: munged is not working, see /var/log/munge/munged.log"
    exit 1
fi
echo "munged is up and running."
