terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# GitHub Actions OIDC provider — short-lived credentials, no static secrets.
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = { ManagedBy = "terraform", Environment = var.environment }
}

# Role assumed by GitHub Actions workflows.
resource "aws_iam_role" "github_actions" {
  name = "titanedge-nexus-${var.environment}-github-actions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*"
        }
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = { Environment = var.environment, ManagedBy = "terraform" }
}

resource "aws_iam_role_policy" "github_actions_terraform" {
  name = "terraform-state-access"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "StateAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.state_bucket}",
          "arn:aws:s3:::${var.state_bucket}/*"
        ]
      },
      {
        Sid    = "StateLocking"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem", "dynamodb:PutItem",
          "dynamodb:DeleteItem", "dynamodb:DescribeTable"
        ]
        Resource = "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${var.lock_table}"
      },
      {
        # CKV_AWS_355: scope to specific cluster ARNs instead of "*".
        # eks:ListClusters has no resource-level permission support so it needs "*",
        # but eks:DescribeCluster can be scoped to the specific cluster.
        Sid      = "EKSDescribeCluster"
        Effect   = "Allow"
        Action   = ["eks:DescribeCluster"]
        Resource = "arn:aws:eks:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:cluster/titanedge-nexus-${var.environment}"
      },
      {
        # eks:ListClusters genuinely does not support resource-level restrictions.
        Sid      = "EKSListClusters"
        Effect   = "Allow"
        Action   = ["eks:ListClusters"]
        Resource = "*"
      }
    ]
  })
}

# KMS key for DynamoDB state lock table (CKV_AWS_119).
resource "aws_kms_key" "dynamo_lock" {
  description             = "TitanEdge Nexus ${var.environment} — Terraform state lock table encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = { Environment = var.environment, ManagedBy = "terraform" }
}

resource "aws_kms_alias" "dynamo_lock" {
  name          = "alias/titanedge-nexus-${var.environment}-lock"
  target_key_id = aws_kms_key.dynamo_lock.key_id
}

# DynamoDB table for state locking.
resource "aws_dynamodb_table" "terraform_locks" {
  name         = var.lock_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery { enabled = true }
  deletion_protection_enabled = var.environment == "prod"

  # CKV_AWS_119: encrypt with a customer-managed KMS key.
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.dynamo_lock.arn
  }

  tags = {
    Name        = var.lock_table
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
