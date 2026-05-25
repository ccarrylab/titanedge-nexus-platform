terraform {
  backend "s3" {
    key     = "titanedge-nexus-platform/prod/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}
