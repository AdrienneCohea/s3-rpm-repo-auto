# S3 RPM Repository Auto-Indexer

An automated solution for managing an RPM repository hosted on Amazon S3. This project uses Amazon S3, SQS, and a containerized Lambda function to automatically update the repository metadata (`repodata`) whenever RPM files are added or removed.

## Features

- **Automated Indexing**: Automatically triggers `createrepo_c` on S3 object changes.
- **S3 Mountpoint for Lambda**: Uses the S3 Access Point to mount the bucket directly to the Lambda function for efficient indexing.
- **Concurrency Control**: Ensures metadata integrity by limiting Lambda execution to a single concurrent instance.
- **VPC Integrated**: Securely processes data within a VPC.
- **Infrastructure as Code**: Fully provisioned via Terraform.

## Architecture

1.  **S3 Bucket**: Stores the RPM packages and the generated `repodata`.
2.  **S3 Event Notifications**: Monitors for `.rpm` file creation or removal.
3.  **SQS Queue**: Buffers event notifications and triggers the Lambda function.
4.  **Lambda Function**:
    -   Built on **Amazon Linux 2023**.
    -   Mounts the S3 bucket at `/mnt/repo` via an **S3 Access Point**.
    -   Runs `createrepo_c` to initialize or update the repository metadata.
5.  **ECR**: Hosts the container image for the Lambda function.

## Prerequisites

-   AWS CLI configured with appropriate permissions.
-   Terraform >= 1.0.
-   Docker (for building the Lambda image).
-   Python 3.x.

## Repository Structure

```text
.
├── lambda-image/
│   ├── Dockerfile       # Container definition for the indexer
│   └── index.py         # Lambda handler logic
├── terraform/           # Infrastructure as Code
│   ├── main.tf          # Core resources (S3, SQS, Lambda)
│   ├── vpc.tf           # Network configuration
│   ├── iam.tf           # Security roles and policies
│   └── variables.tf     # Customizable inputs
└── todo.md              # Project status and roadmap
```

## Deployment

### 1. Build and Push the Lambda Image

Before deploying the infrastructure, you need to push the container image to ECR.

```bash
# Note: You can create the ECR repo via Terraform first, 
# then push the image and update the Lambda.

# 1. Login to ECR
aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <aws_account_id>.dkr.ecr.<region>.amazonaws.com

# 2. Build the image
docker build -t s3-rpm-repo-lambda ./lambda-image

# 3. Tag and Push
docker tag s3-rpm-repo-lambda:latest <aws_account_id>.dkr.ecr.<region>.amazonaws.com/s3-rpm-repo-lambda:latest
docker push <aws_account_id>.dkr.ecr.<region>.amazonaws.com/s3-rpm-repo-lambda:latest
```

### 2. Deploy Infrastructure

```bash
cd terraform
terraform init
terraform apply
```

## Configuration

You can customize the deployment by overriding variables in `terraform/variables.tf` or using a `.tfvars` file:

| Variable | Description | Default |
| :--- | :--- | :--- |
| `aws_region` | AWS region to deploy into | `us-east-1` |
| `project_name` | Prefix for resource naming | `s3-rpm-repo` |
| `vpc_id` | Existing VPC ID (optional) | `null` |
| `ecr_image_tag` | Tag of the image to deploy | `latest` |

## Outputs

After running `terraform apply`, you will get several useful outputs:

- `s3_bucket_name`: The name of the S3 bucket where you should upload your RPMs.
- `ecr_repository_url`: The URL of the ECR repository for your Lambda image.
- `lambda_function_name`: The name of the indexer Lambda function.
- `sqs_queue_url`: The URL of the SQS queue that handles notifications.

## Usage

1.  **Upload an RPM**:
    ```bash
    aws s3 cp my-package.rpm s3://<your-bucket-name>/
    ```
2.  **Monitor Progress**:
    -   Check the SQS queue for messages.
    -   View Lambda logs in CloudWatch to see `createrepo_c` output.
3.  **Verify Repository**:
    -   The `repodata/` directory should appear/update in the S3 bucket.
    -   You can now point `yum` or `dnf` clients to the S3 bucket URL.

## Security Note

This project configures the S3 bucket with versioning and lifecycle policies. Ensure that the IAM roles and Security Groups are reviewed to meet your organization's specific security requirements.
