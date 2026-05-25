terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_cloudwatch_log_group" "platform" {
  name              = "/titanedge-nexus/platform"
  retention_in_days = 30

  tags = {
    Environment = "platform"
    ManagedBy   = "terraform"
  }
}
