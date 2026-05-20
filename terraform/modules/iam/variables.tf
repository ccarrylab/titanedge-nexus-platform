variable "environment" {
  description = "Environment name"
  type        = string
}

variable "github_org" {
  description = "GitHub organisation name (e.g. ccarrylab)"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (e.g. titanedge-nexus-platform)"
  type        = string
}

variable "state_bucket" {
  description = "S3 bucket name for Terraform remote state"
  type        = string
}

variable "lock_table" {
  description = "DynamoDB table name for state locking"
  type        = string
  default     = "titanedge-nexus-terraform-locks"
}
