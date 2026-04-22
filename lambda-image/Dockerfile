# Use Amazon Linux 2023 as the base image
FROM amazonlinux:2023

# Update system and install dependencies
# - dnf upgrade: patches known vulnerabilities in the base image
# - createrepo_c: pinned for reproducibility
RUN dnf upgrade -y && \
    dnf install -y \
    createrepo_c-0.20.0-1.amzn2023.0.3 \
    python3-3.9.25-1.amzn2023.0.4 \
    python3-pip \
    && dnf clean all

# Set the working directory
WORKDIR /var/task

# Install RIC with pinning and without cache
RUN pip3 install --no-cache-dir awslambdaric==4.0.0

# Create a non-root user
RUN groupadd -g 1001 lambdauser && \
    useradd -u 1001 -g lambdauser -s /bin/sh lambdauser

# Copy script and set ownership
COPY index.py .
RUN chown -R lambdauser:lambdauser /var/task

USER lambdauser

ENTRYPOINT [ "/usr/bin/python3", "-m", "awslambdaric" ]
CMD [ "index.handler" ]
