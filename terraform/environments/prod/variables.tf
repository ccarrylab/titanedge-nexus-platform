variable "environment" {
  type = string
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_cidr" {
  type = string
}

variable "availability_zones" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.2.101.0/24", "10.2.102.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.2.1.0/24", "10.2.2.0/24"]
}

# Per-AZ NAT for HA in prod (see README "Environment differences").
variable "single_nat_gateway" {
  type    = bool
  default = false
}

variable "cluster_version" {
  type    = string
  default = "1.35"
}

# Restrict to office/VPN CIDRs in prod — do not leave as 0.0.0.0/0.
variable "eks_public_access_cidrs" {
  type    = list(string)
  default = ["YOUR.OFFICE.IP/32"]
}

variable "node_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 4
}

variable "db_name" {
  type    = string
  default = "platform"
}

variable "rds_instance_class" {
  type    = string
  default = "db.t3.medium"
}

# Multi-AZ for HA in prod (see README "Environment differences").
variable "rds_multi_az" {
  type    = bool
  default = true
}

# Deletion protection enabled in prod (see README "Environment differences").
variable "rds_deletion_protection" {
  type    = bool
  default = true
}

variable "rds_skip_final_snapshot" {
  type    = bool
  default = false
}

variable "redis_node_type" {
  type    = string
  default = "cache.t3.small"
}
