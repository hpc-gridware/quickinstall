# quickinstall

## Adding a New OCS Version

### Files to update
These files are identical and must always be updated together:
- `ocs.sh` (root)
- `containers/openSUSE/15.6/ocs.sh`
- `containers/Rocky/9/ocs.sh`

### Since 9.1.6: stable URLs on open.clusterscheduler.io

Since 9.1.6 packages are published on `https://open.clusterscheduler.io`
(overview: `https://open.clusterscheduler.io/automation`) under a stable
naming scheme, so no per-file ID scraping is needed anymore:

```
https://open.clusterscheduler.io/download/ocs-X.Y.Z/ocs-X.Y.Z-bin-<arch>.tar.gz
https://open.clusterscheduler.io/download/ocs-X.Y.Z/ocs-X.Y.Z-common.tar.gz
https://open.clusterscheduler.io/download/ocs-X.Y.Z/ocs-X.Y.Z-doc.tar.gz
```

`get_clusterscheduler_url()` in `ocs.sh` builds these URLs. For a new version
X.Y.Z (9.1.6 or later) only these updates are needed in both files:

1. Add a `"X.Y.Z") get_clusterscheduler_url "$version" "$arch" ;;` case in
   `get_download_urls()` and extend the error message in the `*)` fallback.
2. Update the default: `OCS_VERSION="${OCS_VERSION:-X.Y.Z}"`.
3. Add `"X.Y.Z"` to the `main()` validation pipe list and its error message.
4. Verify the URLs live (HTTP 200 and gzip payload, see below).

The site also mirrors all older versions. Their hardcoded
`hpc-gridware.com` links stay the default, but setting
`OCS_DOWNLOAD_SOURCE=clusterscheduler` makes `get_download_urls()` fetch any
version from `open.clusterscheduler.io` instead. Discovery API:
`https://open.clusterscheduler.io/api/versions`. Rate limit: 30 downloads
and 60 API calls per minute per client.

### Versions up to 9.1.5 (hpc-gridware.com download pages)

1. **Fetch the download page** for the new version, e.g. `https://hpc-gridware.com/download-ocs-X-Y-Z/`
   - Extract all href links containing `/download/` to get the numeric IDs and `tmstv` values.
   - Required packages: `bin-lx-amd64`, `bin-lx-arm64`, `bin-ulx-amd64`, `common`, `doc`

2. **In `get_download_urls()`** add a new `case` block for the version (after the last existing one, before `*)`):
   ```sh
   "X.Y.Z")
       case "$arch" in
           "lx-amd64")
               echo "https://hpc-gridware.com/download/NNNNN/?tmstv=XXXXXXXXXX"
               ;;
           "lx-arm64")
               echo "https://hpc-gridware.com/download/NNNNN/?tmstv=XXXXXXXXXX"
               ;;
           "ulx-amd64")
               echo "https://hpc-gridware.com/download/NNNNN/?tmstv=XXXXXXXXXX"
               ;;
           "doc")
               echo "https://hpc-gridware.com/download/NNNNN/?tmstv=XXXXXXXXXX"
               ;;
           "common")
               echo "https://hpc-gridware.com/download/NNNNN/?tmstv=XXXXXXXXXX"
               ;;
           *)
               echo ""
               ;;
       esac
       ;;
   ```
   Also update the error message in the `*)` fallback to list the new version.

3. **Update the default version** near the top of each file:
   ```sh
   OCS_VERSION="${OCS_VERSION:-X.Y.Z}"
   ```

4. **Update `main()` version validation** — add `"X.Y.Z"` to the supported versions pipe list and update the error message string.

## Container Directories: Cross-Distro File Parity

`containers/openSUSE/15.6/` and `containers/Rocky/9/` provide the same
single-node and 3-node cluster setup. Distro knowledge lives only in the two
Dockerfiles and the README of each directory; everything else is an identical
copy that must be changed in both places (do not abstract this - two distros
do not justify a shared core, and Docker build contexts cannot reach outside
their directory anyway).

Files that must stay byte-identical across the distro directories:
`docker-compose.yml`, `startup-master.sh`, `startup-worker.sh`,
`preflight.sh`, `ocs-env.sh`, `ocs-banner.sh`, `ocs.sh`, `start-munged.sh`,
`.gitignore`.

Check parity (no output means in sync):

```bash
for f in docker-compose.yml startup-master.sh startup-worker.sh \
         preflight.sh ocs-env.sh ocs-banner.sh ocs.sh start-munged.sh .gitignore; do
    diff containers/openSUSE/15.6/$f containers/Rocky/9/$f
done
```

Both clusters use the same container names and the 10.100.0.0/16 subnet
(hardcoded in the startup scripts and compose files to keep them identical),
so only one distro cluster can run on a host at a time.

## MUNGE and slurm-shim

`ocs.sh` has two opt-in switches, both enabled by default in all container
images (compose: `OCS_MUNGE=${OCS_MUNGE:-true}`, single node: `ENV`):

- `OCS_MUNGE=true`: `setup_munge()` installs munge, creates
  `/etc/munge/munge.key` if missing (never overwrites one) and starts munged,
  then OCS is installed with `inst_sge -munge`. Ignored with a warning for
  9.0.x (MUNGE exists since 9.1.0).
- `OCS_SLURM_SHIM=true`: `install_slurm_shim()` runs the latest slurm-shim
  release `install.sh` (checksum-verified, `$SGE_ROOT/slurm-shim`, creates PE
  `slurm-shim` and queue `slurm.q`) and sets `execd_params
  ENABLE_ADDGRP_KILL=TRUE`. A failure is a warning, not a failed install.
  `SLURM_SHIM_VERSION` pins a release (its install.sh and tarball).

**inst_sge pre-check patch.** In `-auto` mode `inst_sge -munge` runs
`systemctl status munge.service` whenever a `systemctl` binary exists and
aborts if it fails. The munge packages pull in systemd, but systemd is not
PID 1 in containers, so the check always fails there. `install_ocs()` seds
the `type systemctl` line in the unpacked
`util/install_modules/inst_common.sh` into the PID 1 test that
`util/arch_variables` uses (same idea as the `util/arch` and `filestat`
patches). A PATH wrapper for `systemctl` does not work: `inst_sge` hardcodes
`PATH`. Drop the patch once upstream fixes the check in all supported 9.1.x.

In the containers the key is created by the master (via `ocs.sh`) in the
`munge-key` volume (`/etc/munge`, read-only on workers); no image may contain
a key (the openSUSE package generates one, the Dockerfiles delete it).
Workers and restarting masters run `start-munged` when the shared
`bootstrap` file says `security_mode munge`, so the installation decides,
not an environment variable. The single-node `/startup.sh` (generated in the
Dockerfiles) does the same on a container restart and then starts the daemons.

slurm-shim's own test cluster (`slurm-shim/test/cluster/`) builds on
`containers/openSUSE/15.6` and installs a dev build; it has to start the
cluster with `OCS_SLURM_SHIM=false`.
