module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["ap-south-1a", "ap-south-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_support   = true
  enable_dns_hostnames = true

  # ✅ FIX: Updated tags — removed deprecated kubernetes.io/cluster/<name>=shared
  # EKS 1.30+ uses only role tags for subnet discovery
  # private_subnet_tags = {
  #   "kubernetes.io/role/internal-elb" = "1"
  # }

  # public_subnet_tags = {
  #   "kubernetes.io/role/elb" = "1"
  # }

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}