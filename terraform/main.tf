
data "aws_caller_identity" "current" {}

module "argocd" {
  source = "./argocd"
}