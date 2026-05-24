terraform {
  backend "s3" {
    bucket = "atlasrelay-terraform-state"
    key    = "dev/terraform.tfstate"
    region = "us-east-1"
  }
}
