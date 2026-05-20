# RDS Module

PostgreSQL on RDS: encrypted storage, no public access, automated backups,
CloudWatch log exports. Master password auto-generated and stored in
AWS Secrets Manager — never in source control or state (sensitive output).
Retrieve via: `aws secretsmanager get-secret-value --secret-id <secret_arn>`
