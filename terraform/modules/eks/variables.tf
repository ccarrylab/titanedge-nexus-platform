variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, stage, prod)"
  type        = string
  default     = "dev"
}

variable "subnet_ids" {
  description = "Subnet IDs for the cluster and node group (private subnets recommended)"
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "EKS requires subnets in at least two availability zones."
  }
}

# CKV_AWS_339: must be a currently supported Kubernetes version.
# AWS supports 1.29–1.32 as of June 2026; bump this as AWS releases new versions.
variable "cluster_version" {
  description = "Kubernetes version (pinned so upgrades are explicit)"
  type        = string
  default     = "1.32"

  validation {
    condition     = contains(["1.29", "1.30", "1.31", "1.32", "1.33", "1.34", "1.35"], var.cluster_version)
    error_message = "cluster_version must be a currently supported EKS version (1.29–1.35)."
  }
}

# CKV_AWS_39 / CKV_AWS_38: set false + empty cidrs in prod tfvars to lock down endpoint.
variable "endpoint_public_access" {
  description = "Whether the API endpoint is reachable from the internet. Set false in prod."
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "CIDRs allowed to reach the public API endpoint. Restrict to office/VPN CIDRs in non-dev environments."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# Note: cluster_log_types variable removed — all five log types are hardcoded
# in main.tf to prevent accidental omission (CKV_AWS_37).

variable "node_instance_types" {
  description = "EC2 instance types for the managed node group"
  type        = list(string)
  default     = ["t3.small"]
}

variable "node_capacity_type" {
  description = "ON_DEMAND or SPOT"
  type        = string
  default     = "ON_DEMAND"

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.node_capacity_type)
    error_message = "node_capacity_type must be ON_DEMAND or SPOT."
  }
}

variable "node_min_size" {
  description = "Minimum nodes"
  type        = number
  default     = 1
}

variable "node_desired_size" {
  description = "Desired nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum nodes"
  type        = number
  default     = 2
}
