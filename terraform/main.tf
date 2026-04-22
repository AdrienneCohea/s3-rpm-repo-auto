resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# S3 Bucket
resource "aws_s3_bucket" "repo" {
  bucket = "${var.project_name}-repo-${random_id.bucket_suffix.hex}"

  tags = {
    Name = "${var.project_name}-repo"
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

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
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
  name = "${var.project_name}-dlq"
}

resource "aws_sqs_queue" "repo_queue" {
  name = "${var.project_name}-queue"
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
  name                 = "${var.project_name}-lambda"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

# Lambda Function (Placeholder image URI, will be updated during deployment)
resource "aws_lambda_function" "repo_indexer" {
  function_name = "${var.project_name}-indexer"
  role          = aws_iam_role.lambda_role.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.repo_lambda.repository_url}:latest"

  vpc_config {
    subnet_ids         = local.subnet_ids
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  # S3 Mount - Using the file_system_config (assuming support for S3 AP ARN)
  # Note: In some terraform versions, this might need a specific provider version or might be handled differently.
  # If it fails, it might need to be EFS, but the requirement specifically said S3 Files.
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
