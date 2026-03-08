###########################################
# ARGOCD APPLICATION (GitOps)
###########################################

resource "kubernetes_manifest" "web_app_prod" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "web-app-prod"
      namespace = "argocd"
    }
    spec = {
      project = "default"
      source = {
        repoURL        = "git@github.com:gitsohel1030/eks-devops-gitops.git"
        targetRevision = "main"
        path           = "k8s/overlays/prod"
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "prod-app"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = ["CreateNamespace=true"]
      }
    }
  }

  depends_on = [
    helm_release.argocd,
    kubernetes_secret_v1.argocd_ssh,
    kubernetes_config_map_v1.argocd_cm
  ]
}