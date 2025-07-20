FROM opensuse/leap:15.5

# Install dependencies needed for OCS installation and testing
RUN zypper refresh && \
    zypper install -y \
        git-core tar binutils sudo make wget bash \
        gzip hostname iputils net-tools \
        openssh openssh-clients \
        which curl procps cron && \
    zypper clean -a

# Create a non-root user for testing
RUN useradd -m -s /bin/bash testuser && \
    echo "testuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Set up SSH for multi-node testing
RUN ssh-keygen -A && \
    mkdir -p /home/testuser/.ssh && \
    ssh-keygen -t rsa -f /home/testuser/.ssh/id_rsa -N "" && \
    cp /home/testuser/.ssh/id_rsa.pub /home/testuser/.ssh/authorized_keys && \
    chown -R testuser:users /home/testuser/.ssh && \
    chmod 700 /home/testuser/.ssh && \
    chmod 600 /home/testuser/.ssh/authorized_keys

# Copy test scripts (these will be mounted at runtime)
# COPY ../common /opt/test-scripts/
# COPY ../ocs.sh /opt/ocs.sh

# Create shared directory for cluster setup
RUN mkdir -p /opt/ocs && chown testuser:users /opt/ocs

WORKDIR /home/testuser
USER testuser

# Default command - keep container running
CMD ["/bin/bash", "-c", "while true; do sleep 30; done"]