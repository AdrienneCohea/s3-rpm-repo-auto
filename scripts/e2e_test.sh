#!/bin/bash
set -e

# Configuration
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REPO_NAME="s3-rpm-repo-lambda"
IMAGE_TAG="latest"

echo "Account ID: $ACCOUNT_ID"

# 1. Build the image
echo "Building the image..."
docker build -t "$REPO_NAME" ./lambda-image

# 2. Create ECR repo if it doesn't exist (or let Terraform do it)
# We'll let Terraform create it first, then push. 
# But wait, Terraform needs the image URI to create the Lambda if we want it to be ready.
# Actually, the Terraform config has local.ecr_repo_url.

cd terraform
echo "Initializing Terraform..."
terraform init

echo "Applying Terraform (Creating ECR and S3)..."
terraform apply -auto-approve

# Get outputs
S3_BUCKET=$(terraform output -raw s3_bucket_name)
ECR_REPO_URL=$(terraform output -raw ecr_repository_url)
REGION=$(terraform output -raw aws_region)

echo "S3 Bucket: $S3_BUCKET"
echo "ECR Repo: $ECR_REPO_URL"
echo "Region: $REGION"

# 3. Push to ECR
echo "Logging into ECR..."
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$ECR_REPO_URL"

echo "Tagging and pushing image..."
docker tag "${REPO_NAME}:latest" "${ECR_REPO_URL}:${IMAGE_TAG}"
docker push "${ECR_REPO_URL}:${IMAGE_TAG}"

# 4. Update Lambda to use the new image (Terraform apply again to ensure Lambda is updated)
echo "Updating Lambda with the pushed image..."
terraform apply -auto-approve

# 5. Upload Dummy RPM
echo "Uploading dummy RPM to S3..."
aws s3 cp ../test-artifacts/hello-world-1.0-1.noarch.rpm "s3://${S3_BUCKET}/"

# 6. Poll for repodata
echo "Waiting for indexing to complete (polling S3)..."
MAX_RETRIES=12
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if aws s3 ls "s3://${S3_BUCKET}/repodata/repomd.xml" > /dev/null 2>&1; then
        echo "SUCCESS: Indexing completed. repodata/repomd.xml found."
        break
    fi
    echo "Waiting... ($RETRY_COUNT/$MAX_RETRIES)"
    sleep 10
    RETRY_COUNT=$((RETRY_COUNT + 1))
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "FAILURE: Indexing timed out."
    exit 1
fi

echo "E2E Test completed successfully!"
