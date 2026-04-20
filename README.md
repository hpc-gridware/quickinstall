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

The subdirectory contains a multi-node container installation using docker compose.
