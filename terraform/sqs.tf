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
  visibility_timeout_seconds        = 300
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
