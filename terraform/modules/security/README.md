# Security Module

Four VPC-bound security groups with least-privilege rules:
- ALB: internet → 443/80
- EKS nodes: ALB → nodes, node-to-node
- RDS: EKS nodes → 5432 only
- Redis: EKS nodes → 6379 only

Every group is explicitly bound to vpc_id — no accidental default VPC placement.
