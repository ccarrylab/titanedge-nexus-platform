module "vpc" {
  source = "../../modules/vpc"

  environment = "prod"
  vpc_cidr    = "10.30.0.0/16"
}

module "eks" {
  source = "../../modules/eks"

  cluster_name = "atlas-prod-eks"
}

module "redis" {
  source = "../../modules/redis"
}

module "security" {
  source = "../../modules/security"
}
