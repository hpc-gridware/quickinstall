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

## Options

Environment variables of `ocs.sh`:

| Variable | Default | Effect |
|---|---|---|
| `OCS_VERSION` | latest supported | OCS release to install |
| `OCS_PACKAGE_DIR` | unset | use pre-downloaded packages from this directory |
| `OCS_DOWNLOAD_SOURCE` | unset | `clusterscheduler` downloads every version from open.clusterscheduler.io |
| `OCS_MUNGE` | `false` | `true` installs munged and OCS with MUNGE authentication (9.1.0 and later) |
| `OCS_SLURM_SHIM` | `false` | `true` also installs [slurm-shim](https://github.com/hpc-gridware/slurm-shim) (`sbatch`, `srun`, ...) |
| `SLURM_SHIM_VERSION` | `latest` | slurm-shim release to install, e.g. `v0.9.1` |

```bash
curl -s https://raw.githubusercontent.com/hpc-gridware/quickinstall/refs/heads/main/ocs.sh | OCS_MUNGE=true OCS_SLURM_SHIM=true sh
```

The container images in `containers/` enable `OCS_MUNGE` and `OCS_SLURM_SHIM`
by default.

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
