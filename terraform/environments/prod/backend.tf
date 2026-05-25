terraform {
  backend "s3" {
    bucket = "atlasrelay-terraform-state"
    key    = "prod/terraform.tfstate"
    region = "us-east-1"
  }
}
