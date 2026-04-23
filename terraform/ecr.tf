locals {
  use_existing_ecr = var.ecr_repository_name != null
  ecr_repo_url     = local.use_existing_ecr ? data.aws_ecr_repository.existing[0].repository_url : aws_ecr_repository.repo_lambda[0].repository_url
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

data "aws_ecr_repository" "existing" {
  count = local.use_existing_ecr ? 1 : 0
  name  = var.ecr_repository_name
}
