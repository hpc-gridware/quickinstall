FROM quay.io/centos/centos:7

# CentOS 7 is EOL, but we'll use vault repositories
RUN sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*.repo && \
    sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*.repo

# Install dependencies needed for OCS installation and testing
RUN yum update -y && \
    yum install -y \
        git tar binutils sudo make wget bash \
        hostname iputils net-tools \
        openssh-server openssh-clients \
        which curl procps crontabs && \
    yum clean all

# Create a non-root user for testing
RUN useradd -m -s /bin/bash testuser && \
    echo "testuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Set up SSH for multi-node testing
RUN ssh-keygen -A && \
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