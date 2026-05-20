variable "environment" { type = string }
variable "vpc_id" { type = string }
# Used to scope the DNS egress rule on EKS nodes to the VPC CIDR only.
variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR block — used to scope DNS egress to within the VPC"
}
