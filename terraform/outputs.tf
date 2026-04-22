output "vpc_id" {
  description = "The ID of the VPC being used"
  value       = local.vpc_id
}

output "private_subnet_ids" {
  description = "The IDs of the private subnets being used"
  value       = local.subnet_ids
}

output "lambda_security_group_id" {
  description = "The ID of the security group being used by the Lambda function"
  value       = local.lambda_sg_id
}

output "s3_bucket_name" {
  value = aws_s3_bucket.repo.id
}

output "s3_bucket_arn" {
  value = aws_s3_bucket.repo.arn
}

output "sqs_queue_url" {
  value = aws_sqs_queue.repo_queue.id
}

output "sqs_queue_arn" {
  value = aws_sqs_queue.repo_queue.arn
}

output "ecr_repository_url" {
  value = aws_ecr_repository.repo_lambda.repository_url
}

output "lambda_function_name" {
  value = aws_lambda_function.repo_indexer.function_name
}

output "s3_access_point_arn" {
  value = aws_s3_access_point.repo_ap.arn
}
