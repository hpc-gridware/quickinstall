# OCS openSUSE 15.6 Container

Open Cluster Scheduler on openSUSE Leap 15.6 — single node or a 3-node Docker Compose cluster. OCS installs automatically on first start.

## Single Node

```bash
docker build -t ocs-opensuse:15.6 .
docker run -it --rm ocs-opensuse:15.6 /bin/bash
```

Pin a version (default is the latest supported):

```bash
docker run -it --rm -e OCS_VERSION=9.0.12 ocs-opensuse:15.6 /bin/bash
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
docker exec -it ocs-master bash    # settings.sh is sourced, prints a command reference
qhost                              # all three nodes registered with the qmaster
qstat -f                           # all three all.q instances - this is what jobs need
```

`qhost` only proves that an execd talks to the qmaster. A node without a queue
instance still shows up there while being unable to run anything, so check
`qstat -f` as well.

Interactive shells of `root` and `gridware` source `/opt/ocs/default/common/settings.sh`
automatically (via `/etc/profile.d/ocs.sh`, wired into both `.bashrc` files) and show a
short command reference. Hide the banner with `touch ~/.hushlogin`.

Submit a test job:

```bash
docker exec -it -u gridware ocs-master bash
echo "hostname && sleep 10" | qsub
qstat
```

## Authentication (MUNGE)

OCS 9.1+ is installed with MUNGE authentication (`inst_sge -munge`): qmaster,
execd and every client command authenticate through `munged`, which runs on
every node. The key is created on the first start of a cluster - images carry
no key - and lives in the `munge-key` volume, mounted at `/etc/munge` on all
nodes. `docker compose down -v` deletes it together with the installation.

```bash
munge -n | unmunge                                   # STATUS: Success (0)
grep security_mode /opt/ocs/default/common/bootstrap # security_mode munge
```

Install without MUNGE: `OCS_MUNGE=false docker compose up -d --build` on the
first start (single node: `docker run -e OCS_MUNGE=false ...`). OCS 9.0.x has
no MUNGE support; it is installed without it automatically. Whether a node
starts `munged` follows the installation (`security_mode` in the bootstrap
file), so switching needs `docker compose down -v`.

Without a running `munged`, client commands print
`failed to munge encode authinfo: Socket communication error` and keep
retrying instead of exiting. Start it again with `start-munged` (as root). If a
node still cannot talk to the qmaster, check `/var/log/munge/munged.log` on
both sides.

## Slurm commands (slurm-shim)

The latest [slurm-shim](https://github.com/hpc-gridware/slurm-shim) release is
installed to `/opt/ocs/slurm-shim`: `sbatch`, `srun`, `squeue`, `scancel`,
`scontrol`, `sinfo`, `sacct` and `salloc` run on top of OCS and are on the
`PATH` of every node. The installer adds a `slurm-shim` parallel environment
and a `slurm.q` queue.

```bash
docker exec -it -u gridware ocs-master bash
sbatch --wrap hostname
squeue
srun -N 2 hostname          # one task on each of two nodes
slurm-shim doctor           # checks the setup (as root)
```

Pin a release with `SLURM_SHIM_VERSION=v0.9.1`, skip it with
`OCS_SLURM_SHIM=false` (first start). The shim needs internet access to
github.com; if that fails, OCS is installed anyway and the master log names
the retry command.

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
| MUNGE key | Docker volume `munge-key`, mounted at `/etc/munge` on all nodes (read-only on workers) |
| User data | `./data` on host, mounted at `/home/gridware` on all nodes |

The `gridware` user (uid 1000) has sudo on all nodes. On Linux hosts, startup chowns `/home/gridware` to uid 1000 — chown `./data` back if your host user differs.

If the subnet conflicts, change `networks.ocs-cluster.ipam.config.subnet` in `docker-compose.yml`.

## Troubleshooting

```bash
docker compose logs ocs-master                 # installation problems
docker exec -it ocs-worker1 ping ocs-master    # worker connectivity
```

Restart daemons manually (inside a container, as root). The start/stop scripts
take `start`, `stop` and `softstop` — there is no `restart`:

```bash
/opt/ocs/default/common/sgemaster stop && /opt/ocs/default/common/sgemaster start   # master only
/opt/ocs/default/common/sgeexecd stop && /opt/ocs/default/common/sgeexecd start
```

A node that is listed by `qhost` but has no `all.q` instance in `qstat -f` runs
an execd without being part of the cluster queue. Nothing can be scheduled on
it, and a job bound to it fails immediately:

```
$ qrsh -l h=ocs-worker1
Your "qrsh" request could not be scheduled, try again later.
```

Each node joins the `@allhosts` host group itself during startup, which is what
creates its queue instance. If that failed — the worker log says so — repeat it
on the affected node:

```bash
qconf -aattr hostgroup hostlist $(hostname) @allhosts
qconf -mattr queue slots "$(nproc)" all.q@$(hostname)
```

## Files

- `docker-compose.yml` — cluster definition
- `Dockerfile` / `Dockerfile.multinode` — single-node / cluster image
- `startup-master.sh` / `startup-worker.sh` — node init scripts
- `start-munged.sh` - starts munged on a node (`/usr/local/sbin/start-munged`)
- `ocs-env.sh` / `ocs-banner.sh` — shell environment and welcome banner (`/etc/profile.d/ocs.sh`, `/etc/ocs-banner.sh`)
- `ocs.sh` — installer (identical copy of the repository root `ocs.sh`)
- `preflight.sh` — host subnet conflict check

## Requirements

Docker Engine 20.10+ with Compose v2, 4GB RAM, 10GB disk.
