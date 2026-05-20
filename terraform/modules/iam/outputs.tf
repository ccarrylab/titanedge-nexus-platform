output "github_actions_role_arn" {
  description = "ARN of the GitHub Actions IAM role — set this as AWS_ROLE_ARN in GitHub secrets"
  value       = aws_iam_role.github_actions.arn
}

output "state_bucket_name" {
  description = "S3 bucket name used for Terraform state"
  value       = var.state_bucket
}

output "lock_table_name" {
  description = "DynamoDB table for state locking"
  value       = aws_dynamodb_table.terraform_locks.name
}
