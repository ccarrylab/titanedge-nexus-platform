terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 5.0" }
    random = { source = "hashicorp/random", version = "~> 3.6" }
  }
}

# CKV_AWS_191: customer-managed KMS key for at-rest encryption.
resource "aws_kms_key" "redis" {
  description             = "TitanEdge Nexus ${var.environment} — ElastiCache Redis encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = { Environment = var.environment, ManagedBy = "terraform" }
}

resource "aws_kms_alias" "redis" {
  name          = "alias/titanedge-nexus-${var.environment}-redis"
  target_key_id = aws_kms_key.redis.key_id
}

# CKV_AWS_31: auth token required when transit_encryption_enabled = true.
resource "random_password" "redis_auth" {
  length  = 32
  special = false # ElastiCache auth tokens must be alphanumeric only
}

resource "aws_elasticache_subnet_group" "main" {
  name       = "titanedge-nexus-${var.environment}-redis"
  subnet_ids = var.subnet_ids

  tags = { Environment = var.environment, ManagedBy = "terraform" }
}

# Store the auth token in Secrets Manager — without this, the generated
# token only exists in Terraform state and applications/operators have no
# supported way to retrieve it to actually connect to Redis.
resource "aws_secretsmanager_secret" "redis_auth" {
  name                    = "titanedge-nexus/${var.environment}/redis/auth-token"
  description             = "ElastiCache Redis AUTH token — managed by Terraform"
  recovery_window_in_days = var.environment == "prod" ? 30 : 0
  kms_key_id              = aws_kms_key.redis.arn

  tags = { Environment = var.environment, ManagedBy = "terraform" }
}

resource "aws_secretsmanager_secret_version" "redis_auth" {
  secret_id = aws_secretsmanager_secret.redis_auth.id
  secret_string = jsonencode({
    auth_token = random_password.redis_auth.result
    host       = aws_elasticache_replication_group.redis.primary_endpoint_address
    port       = 6379
  })
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = "titanedge-nexus-${var.environment}"
  description          = "TitanEdge Nexus ${var.environment} Redis cluster"

  engine             = "redis"
  engine_version     = var.engine_version
  node_type          = var.node_type
  num_cache_clusters = var.environment == "prod" ? 2 : 1
  port               = 6379


  lifecycle {
    ignore_changes = [kms_key_id, auth_token]
  }
  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = var.security_group_ids

  # CKV_AWS_29: at-rest encryption with CMK.
  at_rest_encryption_enabled = true
  kms_key_id                 = aws_kms_key.redis.arn

  # CKV_AWS_30 + CKV_AWS_31: transit encryption with auth token.
  transit_encryption_enabled = true
  auth_token                 = random_password.redis_auth.result

  automatic_failover_enabled = var.environment == "prod"
  multi_az_enabled           = var.environment == "prod"

  maintenance_window       = "mon:05:00-mon:06:00"
  snapshot_retention_limit = var.environment == "prod" ? 7 : 1
  snapshot_window          = "04:00-05:00"

  log_delivery_configuration {
    destination      = "/titanedge-nexus/${var.environment}/redis/slow-logs"
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "slow-log"
  }

  tags = { Environment = var.environment, ManagedBy = "terraform" }
}

# Prevent replacement when adding KMS key to existing cluster
# The kms_key_id can only be set at creation time on ElastiCache.
# For existing clusters, manage encryption separately.
