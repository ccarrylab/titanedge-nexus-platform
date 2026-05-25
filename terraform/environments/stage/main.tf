module "vpc" {
  source = "../../modules/vpc"

  environment = "stage"
  vpc_cidr    = "10.20.0.0/16"
}

module "eks" {
  source = "../../modules/eks"

  cluster_name = "atlas-stage-eks"
}

module "redis" {
  source = "../../modules/redis"
}

module "security" {
  source = "../../modules/security"
}
