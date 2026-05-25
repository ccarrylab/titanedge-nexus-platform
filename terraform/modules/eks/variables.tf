variable "subnet_ids" {
  description = "List of subnet IDs for the EKS cluster"
  type        = list(string)
}


variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}


# Node group variables (adjust to match your module)




