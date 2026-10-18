#!/bin/bash
# Host driver: run the DRMAA latency sweep in a fresh container per OCS version.
#
#   ./download-packages.sh     # once, fills pkg/
#   ./run.sh                   # 9.1.2 9.1.3 9.1.4
#   ./run.sh 9.1.4             # a single version
#
# Each version gets its own container and its own /opt/ocs, so nothing leaks
# between them. Raw output lands in results/<version>.log; summarize.sh
# tabulates it.

set -eu

cd "$(dirname "$0")"

REPO_ROOT="$(cd ../../../.. && pwd)"
VERSIONS="${*:-9.1.2 9.1.3 9.1.4}"
IMAGE=ocs-drmaa-latency:15.6

docker build -q -t "$IMAGE" . > /dev/null
mkdir -p results

for v in $VERSIONS; do
    if [ ! -d "pkg/$v" ]; then
        echo "ERROR: pkg/$v missing - run ./download-packages.sh $v first" >&2
        exit 1
    fi

    name="ocs-drmaa-$(echo "$v" | tr . -)"
    echo "=== $v ==="
    docker rm -f "$name" > /dev/null 2>&1 || true

    # The hostname is fixed so that every version runs against an identically
    # named single-node cluster. ocs.sh comes straight from the repository
    # root, which keeps this reproducer free of a third copy of it.
    docker run -d --name "$name" --hostname drmaa-test --privileged \
        -v "$REPO_ROOT/ocs.sh:/tmp/ocs.sh:ro" \
        -v "$PWD:/repro:ro" \
        -v "$PWD/pkg/$v:/pkg:ro" \
        -e OCS_VERSION="$v" -e OCS_PACKAGE_DIR=/pkg \
        "$IMAGE" -c 'sleep infinity' > /dev/null

    docker exec -e OCS_VERSION="$v" -e OCS_PACKAGE_DIR=/pkg \
        "$name" bash /repro/in-container.sh 2>&1 | tee "results/$v.log"

    docker rm -f "$name" > /dev/null 2>&1 || true
done

echo
echo "=== summary ==="
./summarize.sh
