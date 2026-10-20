# Copyright (C) 2024-2026 Gridware GmbH
# Open Cluster Scheduler Docker Container for openSUSE Leap 15.6

FROM opensuse/leap:15.6

LABEL maintainer="HPC Gridware GmbH"
LABEL description="Open Cluster Scheduler on openSUSE Leap 15.6"
LABEL version="9.1.4"

# Install basic dependencies required by the installation script. munge
# provides the MUNGE authentication of OCS 9.1+, libopenssl3 the TLS
# encryption of OCS 9.1.7+. Its package generates a key
# at install time; that key is deleted so that no image carries one - ocs.sh
# creates a fresh key on first start.
RUN zypper install -y --no-recommends \
    munge \
    libopenssl3 \
    sudo \
    curl \
    ca-certificates \
    gzip \
    tar \
    hostname \
    which \
    man \
    && zypper clean -a \
    && rm -f /etc/munge/munge.key

# Install with MUNGE authentication and the Slurm commands (slurm-shim) by
# default; "docker run -e OCS_MUNGE=false -e OCS_SLURM_SHIM=false" opts out.
# TLS encryption follows the ocs.sh default (on since 9.1.7), -e OCS_TLS=false
# opts out.
ENV OCS_MUNGE=true OCS_SLURM_SHIM=true

# Copy the local quickinstall script with our fixes
COPY ../../../ocs.sh /tmp/ocs.sh
RUN chmod +x /tmp/ocs.sh

# Wire up the OCS shell environment at image build time: openSUSE ships no
# /root/.bashrc at all and does not read /etc/profile.d for the non-login shell
# that "docker exec -it ... bash" creates. The settings.sh path in the comment
# line is the marker ocs.sh greps for, which keeps the installer from appending
# a second, unguarded sourcing line.
COPY ocs-env.sh /etc/profile.d/ocs.sh
COPY ocs-banner.sh /etc/ocs-banner.sh
COPY start-munged.sh /usr/local/sbin/start-munged
RUN chmod 644 /etc/profile.d/ocs.sh /etc/ocs-banner.sh && \
    chmod 755 /usr/local/sbin/start-munged && \
    printf '%s\n' \
      '# Open Cluster Scheduler environment: /opt/ocs/default/common/settings.sh' \
      '. /etc/profile.d/ocs.sh' >> /root/.bashrc

# Create startup script that installs OCS on first run and starts munged and
# the daemons again on a restart. No version is pinned
# here: ocs.sh defaults to the latest supported one, so the default lives in a
# single place and "docker run -e OCS_VERSION=..." selects another one.
RUN echo '#!/bin/bash' > /startup.sh && \
    echo 'if [ ! -d "/opt/ocs" ]; then' >> /startup.sh && \
    echo '    echo "Installing Open Cluster Scheduler..."' >> /startup.sh && \
    echo '    sh /tmp/ocs.sh' >> /startup.sh && \
    echo 'else' >> /startup.sh && \
    echo '    if grep -q "^security_mode.*munge" /opt/ocs/default/common/bootstrap; then' >> /startup.sh && \
    echo '        /usr/local/sbin/start-munged' >> /startup.sh && \
    echo '    fi' >> /startup.sh && \
    echo '    /opt/ocs/default/common/sgemaster' >> /startup.sh && \
    echo '    /opt/ocs/default/common/sgeexecd' >> /startup.sh && \
    echo 'fi' >> /startup.sh && \
    echo 'exec "$@"' >> /startup.sh && \
    chmod +x /startup.sh

# Keep container running with bash shell
ENTRYPOINT ["/startup.sh"]
CMD ["/bin/bash", "-c", "while true; do sleep 3600; done"]
