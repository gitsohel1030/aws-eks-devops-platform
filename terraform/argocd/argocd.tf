###########################################
# ARGOCD INSTALLATION - HELM
###########################################

resource "helm_release" "argocd" {
  name       = "argocd"
  namespace  = "argocd"
  create_namespace = true

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "9.4.7" # Latest stable

  values = [
    file("${path.module}/argocd-values.yaml")
  ]
}