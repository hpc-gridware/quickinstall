FROM ubuntu:24.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies needed for OCS installation and testing
RUN apt-get update && \
    apt-get install -y \
        git tar binutils sudo make wget bash \
        hostname iputils-ping net-tools \
        openssh-server openssh-client \
        curl procps && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create a non-root user for testing
RUN useradd -m -s /bin/bash testuser && \
    echo "testuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Set up SSH for multi-node testing
RUN mkdir -p /var/run/sshd && \
    mkdir -p /home/testuser/.ssh && \
    ssh-keygen -t rsa -f /home/testuser/.ssh/id_rsa -N "" && \
    cp /home/testuser/.ssh/id_rsa.pub /home/testuser/.ssh/authorized_keys && \
    chown -R testuser:testuser /home/testuser/.ssh && \
    chmod 700 /home/testuser/.ssh && \
    chmod 600 /home/testuser/.ssh/authorized_keys

# Copy test scripts (these will be mounted at runtime)
# COPY ../common /opt/test-scripts/
# COPY ../ocs.sh /opt/ocs.sh

# Create shared directory for cluster setup
RUN mkdir -p /opt/ocs && chown testuser:testuser /opt/ocs

WORKDIR /home/testuser
USER testuser

# Default command - keep container running
CMD ["/bin/bash", "-c", "while true; do sleep 30; done"]