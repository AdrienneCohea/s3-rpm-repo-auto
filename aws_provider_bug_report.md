# Bug Report: `aws_s3files_file_system` deletion fails immediately with `FileSystemHasPendingExport`

**Community Note**
* Please vote on this issue by adding a 👍 [reaction](https://blog.github.com/2016-03-10-add-reactions-to-pull-requests-issues-and-comments/) to the original issue to help the community and maintainers prioritize this request.
* Please do not leave "+1" or "me too" comments, as they generate extra noise for issue followers and do not help prioritize the request.
* If you are interested in working on this issue or have submitted a pull request, please leave a comment.

---

**Terraform Version**
1.x.x

**AWS Provider Version**
6.x.x (and 6.41.0+)

**Affected Resource(s)**
* `aws_s3files_file_system`

**Terraform Configuration Files**
```hcl
# Simplified representation of a Lambda mounting the FS
resource "aws_s3files_file_system" "example" {
  bucket   = aws_s3_bucket.repo.arn
  role_arn = aws_iam_role.s3files_role.arn
}

resource "aws_lambda_function" "example" {
  # ... configuration ...
  file_system_config {
    arn              = aws_s3files_access_point.example.arn
    local_mount_path = "/mnt/repo"
  }
}
```

**Debug Output**
```text
Error: deleting S3 Files File System (fs-12345678): FileSystemHasPendingExport: 
The file system cannot be deleted because it has pending data exports to the 
backing S3 bucket.
```

**Expected Behavior**
The provider should treat `FileSystemHasPendingExport` as a retryable error during the `Delete` phase. It should internally poll/retry the deletion (up to a reasonable timeout, e.g., 10-20 minutes) to allow the background S3 synchronization to complete after the consuming resources (like Lambda functions or EC2 instances) have been destroyed or unmounted. 

This would bring the resource into alignment with other AWS resources like `aws_network_interface` or `aws_subnet`, where the provider handles the "latency" of external dependency cleanup.

**Actual Behavior**
Terraform returns a terminal error immediately. This causes `terraform destroy` to fail even when the dependency graph is correct (e.g., Lambda is destroyed first), because the AWS backend requires a few minutes to flush the filesystem cache to S3 before the filesystem becomes "deletable."

**Steps to Reproduce**
1. Deploy an `aws_s3files_file_system` mounted to an `aws_lambda_function`.
2. Trigger the Lambda to write data to the mount point (e.g., running `createrepo_c`).
3. Immediately run `terraform destroy`.
4. The Lambda will be destroyed, but the File System deletion will fail with `FileSystemHasPendingExport`.

**References**
* AWS Documentation on FSx/S3 Files lifecycle states.
* Similar retry logic implemented in `aws_network_interface` for `DependencyViolation` errors.
