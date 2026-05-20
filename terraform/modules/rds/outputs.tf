output "endpoint" { value = aws_db_instance.postgres.endpoint }
output "db_name" { value = aws_db_instance.postgres.db_name }
output "secret_arn" { value = aws_secretsmanager_secret.rds_password.arn }
output "instance_id" { value = aws_db_instance.postgres.id }
