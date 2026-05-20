terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 5.0" }
    random = { source = "hashicorp/random", version = "~> 3.6" }
  }
}

resource "random_password" "master" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# KMS key for Secrets Manager (CKV_AWS_149).
resource "aws_kms_key" "rds_secret" {
  description             = "TitanEdge Nexus ${var.environment} — RDS secret encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = { Environment = var.environment, ManagedBy = "terraform" }
}

resource "aws_kms_alias" "rds_secret" {
  name          = "alias/titanedge-nexus-${var.environment}-rds-secret"
  target_key_id = aws_kms_key.rds_secret.key_id
}

resource "aws_secretsmanager_secret" "rds_password" {
  name                    = "titanedge-nexus/${var.environment}/rds/master-password"
  description             = "RDS master password — managed by Terraform, rotated via Secrets Manager"
  recovery_window_in_days = var.environment == "prod" ? 30 : 0
  # CKV_AWS_149: encrypt secret with a customer-managed KMS key.
  kms_key_id = aws_kms_key.rds_secret.arn

  tags = { Environment = var.environment, ManagedBy = "terraform" }
}

resource "aws_secretsmanager_secret_version" "rds_password" {
  secret_id = aws_secretsmanager_secret.rds_password.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.master.result
    engine   = "postgres"
    host     = aws_db_instance.postgres.address
    port     = 5432
    dbname   = var.db_name
  })
}

resource "aws_db_subnet_group" "main" {
  name       = "titanedge-nexus-${var.environment}-rds"
  subnet_ids = var.subnet_ids

  tags = { Environment = var.environment, ManagedBy = "terraform" }
}

# IAM role for RDS enhanced monitoring (CKV_AWS_118).
resource "aws_iam_role" "rds_monitoring" {
  name = "titanedge-nexus-${var.environment}-rds-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Environment = var.environment, ManagedBy = "terraform" }
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "aws_db_instance" "postgres" {
  identifier     = "titanedge-nexus-${var.environment}"
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.allocated_storage * 2
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = random_password.master.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = var.vpc_security_group_ids
  publicly_accessible    = false

  # checkov:skip=CKV_AWS_157: multi_az is intentionally false in dev to save cost; true in prod tfvars.
  multi_az = var.multi_az

  backup_retention_period = var.backup_retention_days
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  # checkov:skip=CKV_AWS_293: deletion_protection is intentionally false in dev for easy teardown; true in prod tfvars.
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "titanedge-nexus-${var.environment}-final"

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  # CKV_AWS_161: IAM database authentication.
  iam_database_authentication_enabled = true

  # CKV_AWS_226: auto minor version upgrades (patch security fixes automatically).
  auto_minor_version_upgrade = true

  # CKV_AWS_118: enhanced monitoring at 60-second granularity.
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn

  # CKV_AWS_353 + CKV_AWS_354: performance insights encrypted with CMK.
  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  performance_insights_kms_key_id       = aws_kms_key.rds_secret.arn

  tags = { Environment = var.environment, ManagedBy = "terraform" }

  depends_on = [aws_iam_role_policy_attachment.rds_monitoring]
}
