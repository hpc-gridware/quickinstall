# OCS openSUSE 15.6 Container

Open Cluster Scheduler on openSUSE Leap 15.6 — single node or a 3-node Docker Compose cluster. OCS installs automatically on first start.

## Single Node

```bash
docker build -t ocs-opensuse:15.6 .
docker run -it --rm ocs-opensuse:15.6 /bin/bash
```

## Multi-Node Cluster (1 master, 2 workers)

```bash
./preflight.sh              # warns if 10.100.0.0/16 collides with your network
docker compose up -d --build
```

Pin a version (default is the latest supported):

```bash
OCS_VERSION=9.0.12 docker compose up -d --build
```

Verify:

```bash
docker exec -it ocs-master bash    # settings.sh is sourced via .bashrc
qhost                              # all three nodes should be listed
```

Submit a test job:

```bash
docker exec -it -u gridware ocs-master bash
echo "hostname && sleep 10" | qsub
qstat
```

## Common Commands

```bash
docker compose logs -f ocs-master   # watch installation/startup
docker compose down                 # stop (installation is kept)
docker compose down -v              # stop and delete installation
docker compose up -d --build        # start again — works for fresh and existing installs
```

Change OCS version: `docker compose down -v`, then start with the new `OCS_VERSION`. The `-v` is required to remove the old installation from the shared volume.

## Layout

| What | Where |
|---|---|
| Master (qmaster + execd) | `ocs-master`, 10.100.0.10 |
| Workers (execd) | `ocs-worker1/2`, 10.100.0.11/12 |
| OCS installation | Docker volume `ocs-install`, mounted at `/opt/ocs` on all nodes |
| User data | `./data` on host, mounted at `/home/gridware` on all nodes |

The `gridware` user (uid 1000) has sudo on all nodes. On Linux hosts, startup chowns `/home/gridware` to uid 1000 — chown `./data` back if your host user differs.

If the subnet conflicts, change `networks.ocs-cluster.ipam.config.subnet` in `docker-compose.yml`.

## Troubleshooting

```bash
docker compose logs ocs-master                 # installation problems
docker exec -it ocs-worker1 ping ocs-master    # worker connectivity
```

Restart daemons manually (inside a container, as root):

```bash
/opt/ocs/default/common/sgemaster restart   # master only
/opt/ocs/default/common/sgeexecd restart
```

## Files

- `docker-compose.yml` — cluster definition
- `Dockerfile` / `Dockerfile.multinode` — single-node / cluster image
- `startup-master.sh` / `startup-worker.sh` — node init scripts
- `ocs.sh` — installer (identical copy of the repository root `ocs.sh`)
- `preflight.sh` — host subnet conflict check

## Requirements

Docker Engine 20.10+ with Compose v2, 4GB RAM, 10GB disk.
