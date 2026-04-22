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
