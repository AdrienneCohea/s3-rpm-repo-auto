# Implementation Plan: S3 RPM Repository with Lambda Auto-Indexing

## 1. Infrastructure (Terraform)
- [ ] **S3 Bucket:** Create bucket with versioning enabled.
- [ ] **S3 Lifecycle Policy:** Configure a rule to expire non-current versions after 30 days.
- [ ] **VPC Infrastructure:**
    - [ ] Create or identify a VPC with private subnets.
    - [ ] Create an S3 File System mount target in the VPC subnets.
    - [ ] Configure Security Groups to allow NFS (Port 2049) traffic.
- [ ] **SQS Queue:**
    - [ ] Create a standard SQS queue to buffer S3 event notifications.
    - [ ] Configure a redrive policy/DLQ for failed indexing jobs.
- [ ] **S3 Notifications:** Configure the bucket to send `s3:ObjectCreated:*` and `s3:ObjectRemoved:*` events for suffix `.rpm` to the SQS queue.
- [ ] **Lambda Function:**
    - [ ] Configure to run inside the VPC.
    - [ ] Mount the S3 bucket using the **S3 Files** feature at `/mnt/repo`.
    - [ ] Set **Reserved Concurrency to 1** to prevent race conditions.
    - [ ] Set SQS as the event source trigger.
- [ ] **IAM Roles:**
    - [ ] Lambda execution role with VPC access, SQS consumption, and S3 File System permissions.

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
