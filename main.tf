
data "aws_caller_identity" "current" {}

########################################
# VPC Module
########################################
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

########################################
# IAM Role for EKS Managed Node Group
########################################
# ✅ FIX: Explicitly creating node IAM role since create_auto_mode_iam_resources = false
# was set but no IAM was provided — nodes had no role to assume

# resource "aws_iam_role" "eks_node_group_role" {
#   name = "${var.cluster_name}-node-group-role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Principal = {
#           Service = "ec2.amazonaws.com"
#         }
#         Action = "sts:AssumeRole"
#       }
#     ]
#   })

#   tags = {
#     Name        = "${var.cluster_name}-node-group-role"
#     Terraform   = "true"
#     Environment = "dev"
#   }
# }

# # Required managed policies for EKS worker nodes
# resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
#   role       = aws_iam_role.eks_node_group_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
# }

# resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
#   role       = aws_iam_role.eks_node_group_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
# }

# resource "aws_iam_role_policy_attachment" "ecr_read_only" {
#   role       = aws_iam_role.eks_node_group_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
# }

# # Optional but recommended: SSM access for node debugging
# resource "aws_iam_role_policy_attachment" "ssm_policy" {
#   role       = aws_iam_role.eks_node_group_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
# }

########################################
# EKS Module
########################################9107556565
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0" 

  cluster_name    = var.cluster_name
  cluster_version = "1.32"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets 

  cluster_endpoint_public_access = true

  enable_cluster_creator_admin_permissions = true

  cluster_addons = {
    vpc-cni = {
      before_compute = true
      most_recent = true
    }
    eks-pod-identity-agent = {
      before_compute = true
      most_recent = true
    }
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
  }

  # EKS Managed Node Groups
  eks_managed_node_groups = {
    example = {

      instance_types = ["c7i-flex.large"]

      min_size     = 2
      max_size     = 3
      desired_size = 2

      # Disk size in GB for node root volume
      # disk_size = 20

      # ✅ AL2023 is the default for EKS 1.30+ managed node groups
      ami_type = "AL2023_x86_64_STANDARD"

      # Labels for node selection in Kubernetes
      labels = {
        role = "general"
      }

      tags = {
        Terraform   = "true"
        Environment = "dev"
      }
    }
  }

  # access_entries = {                                                          # Only when if I want to give cluster 
  #   # One access entry with a policy associated                               # access to any other person
  #   example = {
  #     kubernetes_groups = []
  #     principal_arn     = "arn:aws:iam::608827180555:user/Sohel"

  #     policy_associations = {
  #       example = {
  #         policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  #         access_scope = {
  #           namespaces = ["default"]
  #           type       = "namespace"
  #         }
  #       }
  #     }
  #   }
  # }


  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}
