terraform {
  backend "s3" {
    key     = "titanedge-nexus-platform/${terraform.workspace}/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}
