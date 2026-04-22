# Use Amazon Linux 2023 as the base image
FROM amazonlinux:2023

# Install dependencies:
# - createrepo_c: for repository indexing
# - python3 and pip: to run the Lambda handler and install the RIC
RUN dnf install -y \
    createrepo_c \
    python3 \
    python3-pip \
    && dnf clean all

# Set the working directory for the Lambda function
WORKDIR /var/task

# Install the Lambda Runtime Interface Client (RIC) for Python
# This is required when using a base image that is not a Lambda-provided base image
RUN pip3 install awslambdaric

# Create a non-root user to run the Lambda function
RUN groupadd -g 1001 lambdauser && \
    useradd -u 1001 -g lambdauser -s /bin/sh lambdauser

# Copy the indexing script into the container
COPY index.py .

# Ensure the non-root user has ownership of the task directory
RUN chown -R lambdauser:lambdauser /var/task

# Switch to the non-root user
USER lambdauser

# Set the entrypoint to the Lambda Runtime Interface Client
# This allows the container to talk to the Lambda Runtime API
ENTRYPOINT [ "/usr/bin/python3", "-m", "awslambdaric" ]

# Set the CMD to the handler function in index.py
CMD [ "index.handler" ]
