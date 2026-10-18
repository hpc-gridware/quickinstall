# Copyright (C) 2026 Gridware GmbH
# Reproducer image for the libdrmaa drmaa_wait() latency investigation.
#
# Single node: qmaster, execd and the DRMAA test client all run in one
# container. The image carries only the base system and a toolchain; ocs.sh,
# the harness and the OCS packages are bind-mounted at run time, so no copy of
# ocs.sh is baked in and none has to be kept in sync here.

FROM opensuse/leap:15.6

RUN zypper install -y --no-recommends \
    sudo curl ca-certificates gzip tar hostname which \
    gcc make binutils procps net-tools iproute2 gawk \
    && zypper clean -a

ENTRYPOINT ["/bin/bash"]
