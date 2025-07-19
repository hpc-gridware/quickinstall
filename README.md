# quickinstall
Scripts for automatic Open Cluster Scheduler installation across Linux distributions.

## Usage

```bash
# Single-node (testing)
./ocs.sh

# or from remote with specific version
curl -s https://raw.githubusercontent.com/hpc-gridware/quickinstall/refs/heads/main/ocs.sh | OCS_VERSION=9.0.7 sh  


# Cluster master (expects empty shared installation directory / NFS: /opt/ocs/)
# Sets up a cron job on the host for execds to join.
OCS_CLUSTER_SECRET=your-hex-key ./ocs.sh

# Execution node (expects empty shared installation directory / NFS: /opt/ocs/)
OCS_INSTALL_MODE=execd OCS_CLUSTER_SECRET=your-hex-key ./ocs.sh
```

## Creating the Cluster Secret

Generate a secure cluster secret:

```bash
# Generate a random 32-byte hex key
openssl rand -hex 32
```

Use this generated key as the `OCS_CLUSTER_SECRET` value for all cluster nodes.

Supports: Ubuntu, RHEL/CentOS/Rocky, SUSE. Includes secure execd registration with HMAC authentication for dynamic cloud environments.
