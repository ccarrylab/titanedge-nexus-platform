# IAM Module

Provisions GitHub Actions OIDC authentication (no static secrets),
DynamoDB state locking, and an encrypted versioned S3 state bucket.

After first apply, set `AWS_ROLE_ARN` in GitHub → Settings → Secrets
to the `github_actions_role_arn` output value.
