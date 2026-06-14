output "environment" { value = var.environment }
output "vpc_id" { value = module.vpc.vpc_id }
output "public_subnet_ids" { value = module.vpc.public_subnet_ids }
output "private_subnet_ids" { value = module.vpc.private_subnet_ids }
output "nat_gateway_ids" { value = module.vpc.nat_gateway_ids }
output "cluster_name" { value = module.eks.cluster_name }
output "cluster_endpoint" { value = module.eks.cluster_endpoint }
output "rds_endpoint" { value = module.rds.endpoint }
output "redis_endpoint" { value = module.redis.primary_endpoint }
output "dashboard_url" { value = module.observability.dashboard_url }
output "rds_secret_arn" { value = module.rds.secret_arn }
output "configure_kubectl" {
  value = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}"
}
