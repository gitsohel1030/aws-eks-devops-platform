module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0" 

  cluster_name    = var.cluster_name
  cluster_version = "1.32"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets 

  enable_irsa = true

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

  access_entries = {                                                          # Only when if I want to give cluster 
    # One access entry with a policy associated                               # access to any other person
    jenkins = {
      kubernetes_groups = []
      principal_arn     = "arn:aws:iam::608827180555:role/jenkins-eks-role"

      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            # namespaces = ["prod-app"]
            type       = "cluster"
          }
        }
      }
    }
  }


  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}