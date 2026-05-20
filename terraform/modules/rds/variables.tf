variable "environment" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "vpc_security_group_ids" {
  type    = list(string)
  default = []
}

variable "db_name" {
  type    = string
  default = "platform"
}

variable "db_username" {
  type    = string
  default = "platformadmin"
}

variable "engine_version" {
  type    = string
  default = "16.14"
}

variable "instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "multi_az" {
  type    = bool
  default = false
}

variable "backup_retention_days" {
  type    = number
  default = 7
}

variable "deletion_protection" {
  type    = bool
  default = false
}

variable "skip_final_snapshot" {
  type    = bool
  default = true
}
