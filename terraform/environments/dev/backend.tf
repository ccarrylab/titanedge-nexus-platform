terraform {
  backend "s3" {
    key     = "titanedge-nexus-platform/dev/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}
