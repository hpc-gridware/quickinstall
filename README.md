# quickinstall
Scripts for a simple and automatic installation of Open Cluster Scheduler

## Example

Quick install of Open Cluster Scheduler 9.0.8 on one node with qmaster and execution
daemon.

```bash
curl -s https://raw.githubusercontent.com/hpc-gridware/quickinstall/refs/heads/main/ocs.sh | OCS_VERSION=9.0.8 sh  
```

The installation of the OCS can be adapted by modifying the installation
template within the script and subsequently executing the script locally.
