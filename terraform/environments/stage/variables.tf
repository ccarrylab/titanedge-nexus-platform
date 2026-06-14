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
  default = ["10.1.101.0/24", "10.1.102.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.1.1.0/24", "10.1.2.0/24"]
}

variable "single_nat_gateway" {
  type    = bool
  default = true
}

variable "cluster_version" {
  type    = string
  default = "1.35"
}

# Restrict to office/VPN CIDRs once known — broad by default like dev.
variable "eks_public_access_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "node_instance_types" {
  type    = list(string)
  default = ["t3.small"]
}

variable "node_desired_size" {
  type    = number
  default = 1
}

variable "node_max_size" {
  type    = number
  default = 2
}

variable "db_name" {
  type    = string
  default = "platform"
}

variable "rds_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "rds_multi_az" {
  type    = bool
  default = false
}

variable "rds_deletion_protection" {
  type    = bool
  default = false
}

variable "rds_skip_final_snapshot" {
  type    = bool
  default = true
}

variable "redis_node_type" {
  type    = string
  default = "cache.t3.micro"
}
