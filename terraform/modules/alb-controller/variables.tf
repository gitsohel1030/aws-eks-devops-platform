variable "cluster_name" {
  type = string
  description = "cluster_name"
}

variable "region" {
  type        = string
  description = "aws region"
  default     = "ap-south-1"
}

variable "oidc_provider_arn" {
  type = string
}

variable "cluster_oidc_issuer_url" {
  type = string
}

variable "vpc_id" {
  type = string
}
