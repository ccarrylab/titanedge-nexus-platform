# Dev environment — the entire platform composed from shared modules.
# Every resource Terraform manages rebuilds from `terraform apply` alone.
# No eksctl, no manual CloudFormation, no out-of-band setup.

# ------------------------------------------------------------------
# IAM: GitHub OIDC + state backend (S3 + DynamoDB)
# ------------------------------------------------------------------
module "iam" {
  source = "../../modules/iam"

  environment  = var.environment
  github_org   = var.github_org
  github_repo  = var.github_repo
  state_bucket = var.state_bucket
  lock_table   = var.lock_table
}

# ------------------------------------------------------------------
# Networking
# ------------------------------------------------------------------
module "vpc" {
  source = "../../modules/vpc"

  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  single_nat_gateway   = var.single_nat_gateway
}

# ------------------------------------------------------------------
# Security groups (tier-isolated, VPC-bound)
# ------------------------------------------------------------------
module "security" {
  source = "../../modules/security"

  environment = var.environment
  vpc_id      = module.vpc.vpc_id
}

# ------------------------------------------------------------------
# Compute: EKS + managed node group (fully Terraform-managed)
# ------------------------------------------------------------------
module "eks" {
  source = "../../modules/eks"

  cluster_name        = "titanedge-nexus-${var.environment}"
  environment         = var.environment
  subnet_ids          = module.vpc.private_subnet_ids
  cluster_version     = var.cluster_version
  public_access_cidrs = var.eks_public_access_cidrs

  node_instance_types = var.node_instance_types
  node_desired_size   = var.node_desired_size
  node_max_size       = var.node_max_size
}

# ------------------------------------------------------------------
# Data: RDS PostgreSQL
# ------------------------------------------------------------------
module "rds" {
  source = "../../modules/rds"

  environment            = var.environment
  subnet_ids             = module.vpc.private_subnet_ids
  vpc_security_group_ids = [module.security.rds_sg_id]

  db_name             = var.db_name
  instance_class      = var.rds_instance_class
  multi_az            = var.rds_multi_az
  deletion_protection = var.rds_deletion_protection
  skip_final_snapshot = var.rds_skip_final_snapshot
}

# ------------------------------------------------------------------
# Cache: ElastiCache Redis
# ------------------------------------------------------------------
module "redis" {
  source = "../../modules/redis"

  environment        = var.environment
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.security.redis_sg_id]
  node_type          = var.redis_node_type
}

# ------------------------------------------------------------------
# Observability: CloudWatch log groups, alarms, dashboard
# ------------------------------------------------------------------
module "observability" {
  source = "../../modules/observability"

  environment  = var.environment
  cluster_name = module.eks.cluster_name
  aws_region   = var.aws_region
}
