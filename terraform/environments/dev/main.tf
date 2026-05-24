module "vpc" {
  source = "../../modules/vpc"

  environment = "dev"
  vpc_cidr    = "10.10.0.0/16"
}

module "eks" {
  source = "../../modules/eks"

  cluster_name = "atlas-dev-eks"
}
