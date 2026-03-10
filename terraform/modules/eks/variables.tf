variable "cluster_name" {
  type = string
  description = "cluster_name"
}

variable "vpc_id" {
  type = string
}

variable "private_subnets" {
  type = list(string)
}