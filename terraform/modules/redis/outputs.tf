output "primary_endpoint" { value = aws_elasticache_replication_group.redis.primary_endpoint_address }
output "reader_endpoint" { value = aws_elasticache_replication_group.redis.reader_endpoint_address }
output "replication_group_id" { value = aws_elasticache_replication_group.redis.id }
output "secret_arn" { value = aws_secretsmanager_secret.redis_auth.arn }
