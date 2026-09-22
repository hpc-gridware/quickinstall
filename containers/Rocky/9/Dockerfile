# Copyright (C) 2024-2026 Gridware GmbH
# Open Cluster Scheduler Docker Container for Rocky Linux 9

# The floating tag 9 always resolves to the latest 9.x patch release;
# rebuild with --pull to pick up a new one.
FROM rockylinux/rockylinux:9

LABEL maintainer="HPC Gridware GmbH"
LABEL description="Open Cluster Scheduler on Rocky Linux 9"

# Install basic dependencies required by the installation script. curl is
# left out on purpose: the base image ships curl-minimal, which is enough
# here and conflicts with the full curl package. procps-ng is required:
# unlike the openSUSE base image, the Rocky base image has no ps, and the
# OCS installer (util/arch_variables, inst_sge) fails without it.
RUN dnf install -y \
    sudo \
    ca-certificates \
    gzip \
    tar \
    hostname \
    which \
    procps-ng \
    man-db \
    && dnf clean all

# Copy the local quickinstall script with our fixes (identical copy of the
# repository root ocs.sh, kept in this directory because the build context
# cannot reach outside of it)
COPY ocs.sh /tmp/ocs.sh
RUN chmod +x /tmp/ocs.sh

# Wire up the OCS shell environment at image build time. /etc/profile.d
# covers login and ssh shells; the .bashrc line covers the interactive
# non-login shell that "docker exec -it ... bash" creates. The settings.sh
# path in the comment line is the marker ocs.sh greps for, which keeps the
# installer from appending a second, unguarded sourcing line.
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
