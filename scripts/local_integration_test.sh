#!/bin/bash
set -e

# Build the image
echo "Building the Lambda image..."
docker build -t s3-rpm-repo-lambda ./lambda-image

# Create a test repository directory
TEST_REPO_DIR=$(pwd)/test-repo-local
rm -rf "$TEST_REPO_DIR"
mkdir -p "$TEST_REPO_DIR"

# Copy the dummy RPM to the test repo
cp test-artifacts/hello-world-1.0-1.noarch.rpm "$TEST_REPO_DIR/"
chmod -R 777 "$TEST_REPO_DIR"

echo "Running the container for initialization..."
docker run --rm \
  -v "$TEST_REPO_DIR":/mnt/repo \
  -e REPO_PATH=/mnt/repo \
  --entrypoint /usr/bin/python3 \
  s3-rpm-repo-lambda index.py

# Verify repodata was created
if [ -d "$TEST_REPO_DIR/repodata" ]; then
    echo "SUCCESS: repodata directory created."
else
    echo "FAILURE: repodata directory not found."
    exit 1
fi

# Run again to verify update logic
echo "Running the container for update..."
docker run --rm \
  -v "$TEST_REPO_DIR":/mnt/repo \
  -e REPO_PATH=/mnt/repo \
  --entrypoint /usr/bin/python3 \
  s3-rpm-repo-lambda index.py

echo "SUCCESS: Local integration test completed."
