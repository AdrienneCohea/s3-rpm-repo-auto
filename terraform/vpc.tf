data "aws_availability_zones" "available" {}

locals {
  use_existing_vpc = var.vpc_id != null
  vpc_id           = local.use_existing_vpc ? var.vpc_id : aws_vpc.main[0].id
  subnet_ids       = local.use_existing_vpc ? var.private_subnet_ids : aws_subnet.private[*].id

  use_existing_sg = var.lambda_security_group_id != null
  lambda_sg_id    = local.use_existing_sg ? var.lambda_security_group_id : aws_security_group.lambda_sg[0].id
}

# tfsec:ignore:aws-ec2-require-vpc-flow-logs-for-all-vpcs
resource "aws_vpc" "main" {
  count                = local.use_existing_vpc ? 0 : 1
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_subnet" "private" {
  count             = local.use_existing_vpc ? 0 : 2
  vpc_id            = aws_vpc.main[0].id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.project_name}-private-${count.index}"
  }
}

resource "aws_security_group" "lambda_sg" {
  count       = local.use_existing_sg ? 0 : 1
  name        = "${var.project_name}-lambda-sg"
  description = "Security group for Lambda function"
  vpc_id      = local.vpc_id

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Allow HTTPS egress to VPC (for endpoints)"
  }

  egress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    prefix_list_ids = [data.aws_prefix_list.s3.id]
    description     = "Allow HTTPS egress to S3"
  }

  tags = {
    Name = "${var.project_name}-lambda-sg"
  }
}

data "aws_prefix_list" "s3" {
  name = "com.amazonaws.${var.aws_region}.s3"
}

# S3 Gateway Endpoint
resource "aws_vpc_endpoint" "s3" {
  count        = local.use_existing_vpc ? 0 : 1
  vpc_id       = local.vpc_id
  service_name = "com.amazonaws.${var.aws_region}.s3"
}

resource "aws_vpc_endpoint_route_table_association" "s3" {
  count           = local.use_existing_vpc ? 0 : 1
  route_table_id  = aws_vpc.main[0].main_route_table_id
  vpc_endpoint_id = aws_vpc_endpoint.s3[0].id
}

# Interface Endpoints for SQS and ECR
resource "aws_security_group" "endpoint_sg" {
  count       = local.use_existing_vpc ? 0 : 1
  name        = "${var.project_name}-endpoint-sg"
  description = "Security group for VPC endpoints"
  vpc_id      = local.vpc_id

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [local.lambda_sg_id]
    description     = "Allow HTTPS from Lambda security group"
  }

  tags = {
    Name = "${var.project_name}-endpoint-sg"
  }
}

resource "aws_vpc_endpoint" "sqs" {
  count               = local.use_existing_vpc ? 0 : 1
  vpc_id              = local.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.sqs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.subnet_ids
  security_group_ids  = [aws_security_group.endpoint_sg[0].id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ecr_api" {
  count               = local.use_existing_vpc ? 0 : 1
  vpc_id              = local.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.subnet_ids
  security_group_ids  = [aws_security_group.endpoint_sg[0].id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  count               = local.use_existing_vpc ? 0 : 1
  vpc_id              = local.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.subnet_ids
  security_group_ids  = [aws_security_group.endpoint_sg[0].id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "logs" {
  count               = local.use_existing_vpc ? 0 : 1
  vpc_id              = local.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.subnet_ids
  security_group_ids  = [aws_security_group.endpoint_sg[0].id]
  private_dns_enabled = true
}
