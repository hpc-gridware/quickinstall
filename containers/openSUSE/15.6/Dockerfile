# Copyright (C) 2024 Gridware GmbH
# Open Cluster Scheduler Docker Container for openSUSE Leap 15.6

FROM opensuse/leap:15.6

LABEL maintainer="HPC Gridware GmbH"
LABEL description="Open Cluster Scheduler 9.0.8 on openSUSE Leap 15.6"
LABEL version="9.0.8"

# Install basic dependencies required by the installation script
RUN zypper install -y --no-recommends \
    sudo \
    curl \
    ca-certificates \
    gzip \
    tar \
    hostname \
    which \
    && zypper clean -a

# Copy the local quickinstall script with our fixes
COPY ../../../ocs.sh /tmp/ocs.sh
RUN chmod +x /tmp/ocs.sh

# Create startup script that installs OCS on first run
RUN echo '#!/bin/bash' > /startup.sh && \
    echo 'if [ ! -d "/opt/ocs" ]; then' >> /startup.sh && \
    echo '    echo "Installing Open Cluster Scheduler..."' >> /startup.sh && \
    echo '    OCS_VERSION=9.0.8 sh /tmp/ocs.sh' >> /startup.sh && \
    echo 'fi' >> /startup.sh && \
    echo 'exec "$@"' >> /startup.sh && \
    chmod +x /startup.sh

# Keep container running with bash shell
ENTRYPOINT ["/startup.sh"]
CMD ["/bin/bash", "-c", "while true; do sleep 3600; done"]
