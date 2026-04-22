# Implementation Plan: S3 RPM Repository with Lambda Auto-Indexing

## 1. Infrastructure (Terraform)
- [x] **S3 Bucket:** Create bucket with versioning enabled.
- [x] **S3 Lifecycle Policy:** Configure a rule to expire non-current versions after 30 days.
- [x] **VPC Infrastructure:**
    - [x] Create or identify a VPC with private subnets.
    - [x] Create an S3 File System mount target in the VPC subnets.
    - [x] Configure Security Groups to allow NFS (Port 2049) traffic.
- [x] **SQS Queue:**
    - [x] Create a standard SQS queue to buffer S3 event notifications.
    - [x] Configure a redrive policy/DLQ for failed indexing jobs.
- [x] **S3 Notifications:** Configure the bucket to send `s3:ObjectCreated:*` and `s3:ObjectRemoved:*` events for suffix `.rpm` to the SQS queue.
- [x] **Lambda Function:**
    - [x] Configure to run inside the VPC.
    - [x] Mount the S3 bucket using the **S3 Files** feature at `/mnt/repo`.
    - [x] Set **Reserved Concurrency to 1** to prevent race conditions.
    - [x] Set SQS as the event source trigger.
- [ ] **IAM Roles:**
    - [x] Lambda execution role with VPC access, SQS consumption, and S3 File System permissions.
- [x] **Security & Hardening:**
    - [x] S3 Bucket: Public access blocked and HTTPS enforced.
    - [x] S3 Bucket: Server-side encryption with SSE-KMS (single key).
    - [x] S3 Bucket: Server access logging enabled.
    - [x] SQS Queue: Encryption with SSE-KMS (single key).
    - [x] IAM: Least privilege enforced for Lambda S3/SQS/KMS access.
    - [x] Network: Restricted Lambda egress to VPC endpoints (SQS, ECR, Logs) and S3.
    - [x] CloudWatch Logs: Explicit log group with retention for Lambda.
    - [x] Container: Configured to run as a non-root user.
    - [x] ECR: Scan on push and KMS encryption enabled.

## 2. Container Image (Lambda)

- [x] **Dockerfile:**
    - [x] Base: Amazon Linux 2023.
    - [x] Install `createrepo_c`.
    - [x] Entrypoint script to handle indexing logic.
- [x] **Indexing Logic:**
    - [x] Check for existence of `/mnt/repo/repodata/`.
    - [x] If NOT exists: Run `createrepo_c /mnt/repo`.
    - [x] If exists: Run `createrepo_c --update /mnt/repo`.
- [ ] **ECR Repository:** Create repository and push the container image.

## 3. Validation & Testing
- [ ] Upload a test RPM to S3.
- [ ] Verify SQS receives the notification.
- [ ] Verify Lambda execution logs in CloudWatch.
- [ ] Verify `repodata/` is created/updated in S3.
- [ ] Test a yum/dnf client against the S3 bucket URL.
