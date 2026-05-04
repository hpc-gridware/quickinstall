# OCS openSUSE 15.6 Container

Open Cluster Scheduler containerized on openSUSE Leap 15.6 with support for both single-node and multi-node configurations.

## Single-Node Setup

For testing OCS on a single container:

**Build:** `docker build -t ocs-opensuse:15.6 .`
**Run:** `docker run -it --rm --name ocs-container1 ocs-opensuse:15.6 /bin/bash`

OCS installs automatically on first container startup.

## Multi-Node Cluster Setup

For a complete multi-node OCS cluster with 1 master and 2 worker nodes using Docker Compose.

### Architecture

- **ocs-master** (10.100.0.10): Master node running qmaster and execd daemons
- **ocs-worker1** (10.100.0.11): Worker node running execd daemon
- **ocs-worker2** (10.100.0.12): Worker node running execd daemon
- **Shared volumes**:
  - `/opt/ocs`: OCS installation (shared across all nodes)
  - `./data`: Host directory mounted as `/home/gridware` (persistent user data)
- **User**: `gridware` (UID 1000) with sudo access across all nodes

### Quick Start

1. **Build and start the cluster:**
   ```bash
   docker-compose up -d
   ```

   By default this installs the latest supported OCS version. To pin a specific
   version, export `OCS_VERSION` before bringing the cluster up (or place it in
   a `.env` file next to `docker-compose.yml`):
   ```bash
   OCS_VERSION=9.0.12 docker-compose up -d
   ```

2. **Check cluster status:**
   ```bash
   docker exec -it ocs-master bash
   source /opt/ocs/default/common/settings.sh
   qhost
   ```

3. **Submit a test job:**
   ```bash
   docker exec -it -u gridware ocs-master bash
   source /opt/ocs/default/common/settings.sh
   echo "hostname && sleep 10" | qsub
   qstat
   ```

### Detailed Usage

#### Starting the Cluster

```bash
# Build and start all nodes
docker-compose up -d

# View logs from all nodes
docker-compose logs -f

# View logs from specific node
docker-compose logs -f ocs-master
```

#### Accessing Nodes

```bash
# Access master node as root
docker exec -it ocs-master bash

# Access master node as gridware user
docker exec -it -u gridware ocs-master bash

# Access worker node
docker exec -it ocs-worker1 bash
```

#### Managing the Cluster

```bash
# Stop the cluster
docker-compose down

# Stop and remove volumes (clean installation)
docker-compose down -v

# Restart specific node
docker-compose restart ocs-worker1

# Scale workers (if needed)
docker-compose up -d --scale ocs-worker1=2
```

#### Verifying Installation

Once the cluster is running, verify the installation:

```bash
docker exec -it ocs-master bash
source /opt/ocs/default/common/settings.sh

# Check all hosts are registered
qhost

# View cluster configuration
qconf -sh    # Show submit hosts
qconf -ss    # Show scheduler hosts
qconf -sel   # Show execution hosts

# Check queue configuration
qconf -sql   # Show queue list
qconf -sq all.q  # Show all.q configuration
```

### Data Persistence

- **OCS Installation**: Stored in Docker volume `ocs-install`, persists across container restarts
- **User Data**: Stored in `./data` directory on host, mounted to `/home/gridware` in all containers
- **Shared Filesystem**: All nodes share the same `/opt/ocs` installation and `/home/gridware` directory

> Note: `docker-compose down` keeps the `ocs-install` volume. Use `docker-compose down -v` to remove it for a clean reinstall.

Create the data directory before starting:
```bash
mkdir -p ./data
chmod 755 ./data
```

### Network Configuration

The cluster uses a custom bridge network with fixed IP addresses:
- Network: 10.100.0.0/16
- Master: 10.100.0.10
- Worker1: 10.100.0.11
- Worker2: 10.100.0.12

All nodes can communicate with each other using hostnames (ocs-master, ocs-worker1, ocs-worker2).

### Troubleshooting

**Installation not completing:**
```bash
# Check master logs
docker-compose logs ocs-master

# Check if master finished installation
docker exec -it ocs-master ls -la /opt/ocs/default/common/
```

**Worker not joining cluster:**
```bash
# Check worker logs
docker-compose logs ocs-worker1

# Verify network connectivity
docker exec -it ocs-worker1 ping ocs-master

# Check /etc/hosts configuration
docker exec -it ocs-worker1 cat /etc/hosts
```

**Daemon not running:**
```bash
# Check daemon status on master
docker exec -it ocs-master bash
source /opt/ocs/default/common/settings.sh
qconf -sh

# Restart daemons if needed
/opt/ocs/default/common/sgemaster restart
/opt/ocs/default/common/sgeexecd restart
```

### Customization

To modify the cluster configuration, edit `docker-compose.yml`:

- Change OCS version: set the `OCS_VERSION` environment variable (or add it to a `.env` file), then run `docker-compose down -v && OCS_VERSION=X.Y.Z docker-compose up -d` — the `-v` is required to remove the existing installation from the shared volume so the new version gets installed. Omit the variable to use the latest supported version.
- Add more workers: Duplicate worker service with new name and IP
- Change network subnet: Update `networks.ocs-cluster.ipam.config.subnet`
- Use host directory for installation: Change `ocs-install` volume to bind mount

### Files

- `docker-compose.yml`: Multi-node cluster orchestration
- `Dockerfile.multinode`: Container image for cluster nodes
- `startup-master.sh`: Master node initialization script
- `startup-worker.sh`: Worker node initialization script
- `ocs.sh`: OCS installation script (copied from repository root)

### Requirements

- Docker Engine 20.10+
- Docker Compose 1.29+
- At least 4GB RAM available for Docker
- 10GB free disk space
