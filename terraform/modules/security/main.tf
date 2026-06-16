terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

# ALB security group — accepts HTTPS from the internet.
resource "aws_security_group" "alb" {
  name        = "titanedge-nexus-${var.environment}-alb"
  description = "ALB: inbound HTTPS from internet, outbound to EKS nodes"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Port 80 intentionally not opened: if an HTTP listener is added for
  # redirect-to-HTTPS, add a scoped ingress rule here at that time.

  # checkov:skip=CKV_AWS_382: ALB needs outbound access to EKS node ports,
  #   which vary by service; restricting egress would break routing.
  egress {
    description = "All outbound to VPC and AWS APIs"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "titanedge-nexus-${var.environment}-alb", Environment = var.environment, ManagedBy = "terraform" }

  lifecycle {
    ignore_changes = [egress, ingress]
  }
}

# EKS nodes — accepts traffic from ALB only.
resource "aws_security_group" "eks_nodes" {
  name        = "titanedge-nexus-${var.environment}-eks-nodes"
  description = "EKS worker nodes: inbound from ALB and within cluster, outbound all"
  vpc_id      = var.vpc_id

  ingress {
    description     = "From ALB"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description = "Node-to-node"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  # checkov:skip=CKV_AWS_382: nodes need outbound access to ECR, EKS API,
  #   and other AWS services for pulling images and CNI/addon traffic.
  egress {
    description = "All outbound to AWS APIs, ECR, and the internet for image pulls"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "titanedge-nexus-${var.environment}-eks-nodes", Environment = var.environment, ManagedBy = "terraform", "karpenter.sh/discovery" = "titanedge-nexus-${var.environment}" }

  lifecycle {
    ignore_changes = [egress, ingress]
  }
}

# RDS — accepts PostgreSQL from EKS nodes only.
resource "aws_security_group" "rds" {
  name        = "titanedge-nexus-${var.environment}-rds"
  description = "RDS: inbound PostgreSQL from EKS nodes only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from EKS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
  }

  tags = { Name = "titanedge-nexus-${var.environment}-rds", Environment = var.environment, ManagedBy = "terraform" }

  lifecycle {
    ignore_changes = [egress, ingress]
  }
}

# Redis — accepts 6379 from EKS nodes only.
resource "aws_security_group" "redis" {
  name        = "titanedge-nexus-${var.environment}-redis"
  description = "Redis: inbound from EKS nodes only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Redis from EKS"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
  }

  tags = { Name = "titanedge-nexus-${var.environment}-redis", Environment = var.environment, ManagedBy = "terraform" }

  lifecycle {
    ignore_changes = [egress, ingress]
  }
}
