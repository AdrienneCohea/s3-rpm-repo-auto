resource "random_id" "bucket_suffix" {
  byte_length = 4
}

locals {
  use_existing_ecr = var.ecr_repository_name != null
  ecr_repo_url     = local.use_existing_ecr ? data.aws_ecr_repository.existing[0].repository_url : aws_ecr_repository.repo_lambda[0].repository_url
}

data "aws_ecr_repository" "existing" {
  count = local.use_existing_ecr ? 1 : 0
  name  = var.ecr_repository_name
}

# S3 Bucket for Logging
# tfsec:ignore:aws-s3-enable-bucket-logging
resource "aws_s3_bucket" "logs" {
  bucket = "${var.project_name}-logs-${random_id.bucket_suffix.hex}"

  tags = {
    Name = "${var.project_name}-logs"
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.main.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

# S3 Bucket

resource "aws_s3_bucket_policy" "logs" {
  bucket = aws_s3_bucket.logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnforceHTTPS"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.logs.arn,
          "${aws_s3_bucket.logs.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# S3 Bucket
resource "aws_s3_bucket" "repo" {
  bucket = "${var.project_name}-repo-${random_id.bucket_suffix.hex}"

  tags = {
    Name = "${var.project_name}-repo"
  }
}

resource "aws_s3_bucket_logging" "repo" {
  bucket = aws_s3_bucket.repo.id

  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "log/"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "repo" {
  bucket = aws_s3_bucket.repo.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.main.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_versioning" "repo" {
  bucket = aws_s3_bucket.repo.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "repo" {
  bucket = aws_s3_bucket.repo.id

  rule {
    id     = "expire-non-current"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

resource "aws_s3_bucket_public_access_block" "repo" {
  bucket = aws_s3_bucket.repo.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "repo" {
  bucket = aws_s3_bucket.repo.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnforceHTTPS"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.repo.arn,
          "${aws_s3_bucket.repo.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# S3 Access Point for Lambda Mount
resource "aws_s3_access_point" "repo_ap" {
  bucket = aws_s3_bucket.repo.id
  name   = "${var.project_name}-ap"

  vpc_configuration {
    vpc_id = local.vpc_id
  }
}

# SQS Queue and DLQ
resource "aws_sqs_queue" "repo_dlq" {
  name                              = "${var.project_name}-dlq"
  kms_master_key_id                 = aws_kms_key.main.id
  kms_data_key_reuse_period_seconds = 300
}

resource "aws_sqs_queue" "repo_queue" {
  name                              = "${var.project_name}-queue"
  kms_master_key_id                 = aws_kms_key.main.id
  kms_data_key_reuse_period_seconds = 300
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.repo_dlq.arn
    maxReceiveCount     = 5
  })
}

resource "aws_sqs_queue_policy" "repo_queue_policy" {
  queue_url = aws_sqs_queue.repo_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.repo_queue.arn
        Condition = {
          ArnLike = {
            "aws:SourceArn" = aws_s3_bucket.repo.arn
          }
        }
      }
    ]
  })
}

# S3 Notification to SQS
resource "aws_s3_bucket_notification" "repo_notification" {
  bucket = aws_s3_bucket.repo.id

  queue {
    queue_arn     = aws_sqs_queue.repo_queue.arn
    events        = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
    filter_suffix = ".rpm"
  }

  depends_on = [aws_sqs_queue_policy.repo_queue_policy]
}

# ECR Repository
resource "aws_ecr_repository" "repo_lambda" {
  count                = local.use_existing_ecr ? 0 : 1
  name                 = "${var.project_name}-lambda"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.main.arn
  }
}

# Lambda Function
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.project_name}-indexer"
  retention_in_days = 14
  kms_key_id        = aws_kms_key.main.arn
}

resource "aws_lambda_function" "repo_indexer" {
  function_name = "${var.project_name}-indexer"
  role          = aws_iam_role.lambda_role.arn
  package_type  = "Image"
  image_uri     = "${local.ecr_repo_url}:${var.ecr_image_tag}"

  tracing_config {
    mode = "Active"
  }

  logging_config {
    log_format = "JSON"
    log_group  = aws_cloudwatch_log_group.lambda.name
  }

  vpc_config {
    subnet_ids         = local.subnet_ids
    security_group_ids = [local.lambda_sg_id]
  }

  # S3 Mount via S3 Files feature (using S3 Access Point)
  file_system_config {
    arn              = aws_s3_access_point.repo_ap.arn
    local_mount_path = "/mnt/repo"
  }

  reserved_concurrent_executions = 1

  timeout     = 300
  memory_size = 512

  depends_on = [
    aws_iam_role_policy_attachment.lambda_vpc_access,
    aws_iam_role_policy_attachment.lambda_sqs_access,
    aws_iam_role_policy_attachment.lambda_s3_access
  ]
}

# SQS Trigger for Lambda
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.repo_queue.arn
  function_name    = aws_lambda_function.repo_indexer.arn
  batch_size       = 1
}
