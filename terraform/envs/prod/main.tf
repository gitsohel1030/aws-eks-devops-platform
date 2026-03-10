
data "aws_caller_identity" "current" {}

module "vpc" {
    source = "../../modules/vpc"
    cluster_name = var.cluster_name
}

module "eks" {
    source = "../../modules/eks"
    cluster_name = var.cluster_name
    vpc_id = module.vpc.vpc_id
    private_subnets = module.vpc.private_subnets
}

module "alb_controller" {
    source = "../../modules/alb-controller"
    cluster_name = var.cluster_name
    vpc_id = module.vpc.vpc_id
    oidc_provider_arn = module.eks.oidc_provider_arn
    cluster_oidc_issuer_url = module.eks.cluster_oidc_issuer_url

    depends_on = [ module.eks ]
}

module "argocd" {
  source = "../../modules/argocd"

  cluster_name = module.eks.cluster_name

  depends_on = [ 
    module.eks,
    module.alb_controller
 ]
}



# module "argocd" {
#   source = "./argocd"

#   depends_on = [
#   module.eks
#   ]
# }

