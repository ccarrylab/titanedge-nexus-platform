output "eks_log_group_name" { value = aws_cloudwatch_log_group.eks_api.name }
output "app_log_group_name" { value = aws_cloudwatch_log_group.application.name }
output "dashboard_url" {
  value = "https://console.aws.amazon.com/cloudwatch/home#dashboards:name=titanedge-nexus-${var.environment}"
}
