terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

locals {
  prefix = "/titanedge-nexus/${var.environment}"
}

# KMS key for CloudWatch log group encryption (CKV_AWS_158).
resource "aws_kms_key" "logs" {
  description             = "TitanEdge Nexus ${var.environment} — CloudWatch log encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "RootAccountFullAccess"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "AllowCloudWatchLogs"
        Effect    = "Allow"
        Principal = { Service = "logs.${var.aws_region}.amazonaws.com" }
        Action    = ["kms:Encrypt*", "kms:Decrypt*", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:Describe*"]
        Resource  = "*"
      }
    ]
  })

  tags = { Environment = var.environment, ManagedBy = "terraform" }
}

resource "aws_kms_alias" "logs" {
  name          = "alias/titanedge-nexus-${var.environment}-logs"
  target_key_id = aws_kms_key.logs.key_id
}

data "aws_caller_identity" "current" {}

# EKS control-plane log groups (one per log type — AWS requires them).
# retention_in_days >= 365 satisfies CKV_AWS_338.
# kms_key_id satisfies CKV_AWS_158.
resource "aws_cloudwatch_log_group" "eks_api" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.logs.arn
  tags              = { Environment = var.environment, ManagedBy = "terraform" }
}

resource "aws_cloudwatch_log_group" "application" {
  name              = "${local.prefix}/application"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.logs.arn
  tags              = { Environment = var.environment, ManagedBy = "terraform" }
}

resource "aws_cloudwatch_log_group" "rds" {
  name              = "${local.prefix}/rds"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.logs.arn
  tags              = { Environment = var.environment, ManagedBy = "terraform" }
}

resource "aws_cloudwatch_log_group" "redis_slow" {
  name              = "${local.prefix}/redis/slow-logs"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.logs.arn
  tags              = { Environment = var.environment, ManagedBy = "terraform" }
}

# EKS node CPU alarm — fires when average exceeds threshold for 2 periods.
resource "aws_cloudwatch_metric_alarm" "eks_node_cpu" {
  alarm_name          = "titanedge-nexus-${var.environment}-eks-node-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "node_cpu_utilization"
  namespace           = "ContainerInsights"
  period              = 300
  statistic           = "Average"
  threshold           = var.cpu_alarm_threshold
  alarm_description   = "EKS node CPU above ${var.cpu_alarm_threshold}%"

  dimensions = { ClusterName = var.cluster_name }

  alarm_actions = var.alarm_sns_arn != "" ? [var.alarm_sns_arn] : []
  ok_actions    = var.alarm_sns_arn != "" ? [var.alarm_sns_arn] : []

  tags = { Environment = var.environment, ManagedBy = "terraform" }
}

# Platform dashboard — a single pane of glass for the ops team.
resource "aws_cloudwatch_dashboard" "platform" {
  dashboard_name = "titanedge-nexus-${var.environment}"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          title   = "EKS Node CPU"
          region  = var.aws_region
          metrics = [["ContainerInsights", "node_cpu_utilization", "ClusterName", var.cluster_name]]
          period  = 300
          stat    = "Average"
        }
      },
      {
        type = "metric"
        properties = {
          title   = "RDS Connections"
          region  = var.aws_region
          metrics = [["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", "titanedge-nexus-${var.environment}"]]
          period  = 300
          stat    = "Average"
        }
      },
      {
        type = "metric"
        properties = {
          title  = "Redis Cache Hits"
          region = var.aws_region
          metrics = [
            ["AWS/ElastiCache", "CacheHits", "ReplicationGroupId", "titanedge-nexus-${var.environment}"],
            ["AWS/ElastiCache", "CacheMisses", "ReplicationGroupId", "titanedge-nexus-${var.environment}"]
          ]
          period = 300
          stat   = "Sum"
        }
      }
    ]
  })
}
