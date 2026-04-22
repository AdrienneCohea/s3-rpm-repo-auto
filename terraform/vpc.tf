data "aws_availability_zones" "available" {}

locals {
  use_existing_vpc = var.vpc_id != null
  vpc_id           = local.use_existing_vpc ? var.vpc_id : aws_vpc.main[0].id
  subnet_ids       = local.use_existing_vpc ? var.private_subnet_ids : aws_subnet.private[*].id
}

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
  name        = "${var.project_name}-lambda-sg"
  description = "Security group for Lambda function"
  vpc_id      = local.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-lambda-sg"
  }
}

resource "aws_security_group" "nfs_sg" {
  name        = "${var.project_name}-nfs-sg"
  description = "Security group for NFS (Port 2049) traffic"
  vpc_id      = local.vpc_id

  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-nfs-sg"
  }
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
