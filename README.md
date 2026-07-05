# quickinstall

Scripts for a simple and automatic installation of Open Cluster Scheduler in 
VMs or containers.

## Example

Quick install of Open Cluster Scheduler on one node with qmaster and execution
daemon. Without setting OCS_VERSION it installs the latest release (like 9.0.9).

```bash
curl -s https://raw.githubusercontent.com/hpc-gridware/quickinstall/refs/heads/main/ocs.sh | OCS_VERSION=9.0.8 sh  
```

The installation of the OCS can be adapted by modifying the installation
template within the script and subsequently executing the script locally.

## Multi-Node

The subdirectory contains a multi-node container installation using docker compose
for (integration) testing.

```bash
docker-compose up -d

# wait until system is installed
docker-compose logs -f

# login to the container
docker exec -it ocs-master bash
```

Inside the container, source the settings and check the cluster:

```console
ocs-master:/ # source /opt/ocs/default/common/settings.sh
ocs-master:/ # qhost
HOSTNAME                ARCH         NCPU  NSOC  NCOR  NTHR   LOAD  MEMTOT  MEMUSE  SWAPTO  SWAPUS
--------------------------------------------------------------------------------------------------
global                  -               -     -     -     -      -       -       -       -       -
ocs-master              lx-arm64       14     1    14    14   2.17    7.7G    3.2G 1024.0M     0.0
ocs-worker1             lx-arm64       14     1    14    14   2.18    7.7G    3.2G 1024.0M     0.0
ocs-worker2             lx-arm64       14     1    14    14   2.18    7.7G    3.2G 1024.0M     0.0
ocs-master:/ #
```
