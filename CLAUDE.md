# quickinstall

## Adding a New OCS Version

### Files to update
Both of these files are identical and must always be updated together:
- `ocs.sh` (root)
- `containers/openSUSE/15.6/ocs.sh`

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
