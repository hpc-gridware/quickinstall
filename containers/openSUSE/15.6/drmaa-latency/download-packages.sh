#!/bin/bash
# Cache the OCS packages for the versions under test into pkg/<version>/.
#
# The download URLs are not repeated here: get_download_urls() is lifted out of
# the repository ocs.sh and called directly, so adding a version to ocs.sh is
# enough to make it available to the reproducer.
#
#   ./download-packages.sh                # 9.1.2 9.1.3 9.1.4
#   ./download-packages.sh 9.1.0 9.1.1    # any versions ocs.sh knows

set -eu

cd "$(dirname "$0")"

REPO_ROOT="$(cd ../../../.. && pwd)"
OCS_SH="$REPO_ROOT/ocs.sh"
VERSIONS="${*:-9.1.2 9.1.3 9.1.4}"

[ -f "$OCS_SH" ] || { echo "ERROR: $OCS_SH not found" >&2; exit 1; }

# ocs.sh is not sourceable as a whole (it runs the installation on load), so
# take just the one function out of it.
eval "$(awk '/^get_download_urls\(\)/,/^}$/' "$OCS_SH")"

case "$(uname -m)" in
    x86_64)        ARCH=lx-amd64 ;;
    aarch64|arm64) ARCH=lx-arm64 ;;
    *) echo "ERROR: unsupported architecture $(uname -m)" >&2; exit 1 ;;
esac
echo "host architecture: $ARCH"

for v in $VERSIONS; do
    mkdir -p "pkg/$v"
    for kind in "bin-$ARCH:$ARCH" "common:common" "doc:doc"; do
        name="${kind%%:*}"
        key="${kind##*:}"
        out="pkg/$v/ocs-$v-$name.tar.gz"

        if [ -s "$out" ]; then
            echo "  have $out"
            continue
        fi

        url="$(get_download_urls "$v" "$key")"
        if [ -z "$url" ]; then
            echo "ERROR: no download URL for $v/$key in ocs.sh" >&2
            exit 1
        fi

        echo "  fetch $out"
        curl -sSL -o "$out" "$url"
        # A redirector that hands back an HTML error page would otherwise only
        # surface much later, as a confusing tar failure inside the container.
        if ! tar tzf "$out" > /dev/null 2>&1; then
            echo "ERROR: $out is not a valid tarball (bad URL or expired link?)" >&2
            rm -f "$out"
            exit 1
        fi
    done
done

echo "packages ready:"
du -sh pkg/*
