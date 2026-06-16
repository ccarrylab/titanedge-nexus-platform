output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_certificate_authority" {
  description = "Base64 cluster CA data"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL for IRSA"
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

output "oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider for IRSA trust policies"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "node_group_name" {
  description = "Managed node group name"
  value       = aws_eks_node_group.default.node_group_name
}

output "karpenter_node_role_name" {
  description = "Name of the IAM role Karpenter-launched nodes assume — set as EC2NodeClass.spec.role"
  value       = aws_iam_role.karpenter_node.name
}
