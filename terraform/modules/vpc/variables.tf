variable "environment" {
  description = "Environment name (dev, stage, prod) used in resource names and tags"
  type        = string

  validation {
    condition     = length(var.environment) > 0 && length(var.environment) <= 32
    error_message = "environment must be a non-empty string of at most 32 characters."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC (must be a valid IPv4 CIDR, /24 or larger)"
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block (e.g. 10.0.0.0/16)."
  }

  validation {
    condition     = can(tonumber(split("/", var.vpc_cidr)[1])) ? tonumber(split("/", var.vpc_cidr)[1]) <= 24 : false
    error_message = "vpc_cidr must be /24 or larger to leave room for subnets."
  }
}

variable "availability_zones" {
  description = "Availability zones to spread subnets across"
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "Use at least two availability zones (EKS requires subnets in two or more AZs)."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per availability zone)"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (one per availability zone)"
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "true = one shared NAT gateway (cheap, dev). false = one NAT per AZ (HA, prod)."
  type        = bool
  default     = true
}
