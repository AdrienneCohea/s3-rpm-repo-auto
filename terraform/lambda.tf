# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.project_name}-indexer"
  retention_in_days = 14
  kms_key_id        = aws_kms_key.main.arn
}

# Lambda Function
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

  # S3 Mount via S3 Files feature
  file_system_config {
    arn              = aws_s3files_access_point.repo_ap.arn
    local_mount_path = var.repo_mount_path
  }

  environment {
    variables = {
      REPO_PATH = var.repo_mount_path
    }
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
