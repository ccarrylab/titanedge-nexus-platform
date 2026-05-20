variable "environment" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

# CKV_AWS_338: log groups must retain for at least 1 year (365 days).
variable "log_retention_days" {
  type    = number
  default = 365
}

variable "cpu_alarm_threshold" {
  type    = number
  default = 80
}

variable "alarm_sns_arn" {
  type    = string
  default = ""
}
