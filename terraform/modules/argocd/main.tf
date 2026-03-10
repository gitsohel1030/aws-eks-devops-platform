resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.argocd_namespace
  }
}

resource "helm_release" "argocd" {
  name = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart = "argo-cd"
  namespace = var.argocd_namespace

  depends_on = [ kubernetes_namespace.argocd ]

  set {
    name = "server.service.type"
    value = "LoadBalancer"
  }

  set {
    name = "configs.params.server\\.insecure"
    value = "true"
  }
}