terraform {
  backend "s3" {
    bucket = "atlasrelay-terraform-state"
    key    = "stage/terraform.tfstate"
    region = "us-east-1"
  }
}
