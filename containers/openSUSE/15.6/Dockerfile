# Copyright (C) 2024-2026 Gridware GmbH
# Open Cluster Scheduler Docker Container for openSUSE Leap 15.6

FROM opensuse/leap:15.6

LABEL maintainer="HPC Gridware GmbH"
LABEL description="Open Cluster Scheduler on openSUSE Leap 15.6"
LABEL version="9.1.4"

# Install basic dependencies required by the installation script
RUN zypper install -y --no-recommends \
    sudo \
    curl \
    ca-certificates \
    gzip \
    tar \
    hostname \
    which \
    man \
    && zypper clean -a

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
RUN chmod 644 /etc/profile.d/ocs.sh /etc/ocs-banner.sh && \
    printf '%s\n' \
      '# Open Cluster Scheduler environment: /opt/ocs/default/common/settings.sh' \
      '. /etc/profile.d/ocs.sh' >> /root/.bashrc

# Create startup script that installs OCS on first run. No version is pinned
# here: ocs.sh defaults to the latest supported one, so the default lives in a
# single place and "docker run -e OCS_VERSION=..." selects another one.
RUN echo '#!/bin/bash' > /startup.sh && \
    echo 'if [ ! -d "/opt/ocs" ]; then' >> /startup.sh && \
    echo '    echo "Installing Open Cluster Scheduler..."' >> /startup.sh && \
    echo '    sh /tmp/ocs.sh' >> /startup.sh && \
    echo 'fi' >> /startup.sh && \
    echo 'exec "$@"' >> /startup.sh && \
    chmod +x /startup.sh

# Keep container running with bash shell
ENTRYPOINT ["/startup.sh"]
CMD ["/bin/bash", "-c", "while true; do sleep 3600; done"]
