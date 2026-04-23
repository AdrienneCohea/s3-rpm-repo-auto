# S3 Files File System for Lambda Mount
resource "aws_s3files_file_system" "repo_fs" {
  bucket   = aws_s3_bucket.repo.arn
  role_arn = aws_iam_role.s3files_role.arn

  tags = {
    Name = "${var.project_name}-fs"
  }
}

resource "aws_s3files_mount_target" "repo_mt" {
  count           = length(local.subnet_ids)
  file_system_id  = aws_s3files_file_system.repo_fs.id
  subnet_id       = local.subnet_ids[count.index]
  security_groups = [local.lambda_sg_id]
}

resource "aws_s3files_access_point" "repo_ap" {
  file_system_id = aws_s3files_file_system.repo_fs.id

  posix_user {
    gid = 1001
    uid = 1001
  }

  root_directory {
    path = "/"

    creation_permissions {
      owner_uid   = 1001
      owner_gid   = 1001
      permissions = "0755"
    }
  }
}
