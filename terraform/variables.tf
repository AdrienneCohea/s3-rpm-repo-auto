variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for tagging and naming"
  type        = string
  default     = "s3-rpm-repo"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_id" {
  description = "ID of an existing VPC to use. If not provided, a new VPC will be created."
  type        = string
  default     = null
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs in the existing VPC. Required if vpc_id is provided."
  type        = list(string)
  default     = []
}

variable "lambda_security_group_id" {
  description = "ID of an existing security group to use for the Lambda function. If not provided, a new one will be created."
  type        = string
  default     = null
}

variable "ecr_repository_name" {
  description = "Name of an existing ECR repository to use. If not provided, a new one will be created."
  type        = string
  default     = null
}

variable "ecr_image_tag" {
  description = "The tag of the image to use for the Lambda function."
  type        = string
  default     = "latest"
}

variable "repo_mount_path" {
  description = "The local mount path for the S3 bucket in the Lambda function."
  type        = string
  default     = "/mnt/repo"
}
