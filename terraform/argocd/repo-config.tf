###########################################
# UPDATE argocd-cm to register SSH Git repo
###########################################

resource "kubernetes_config_map_v1" "argocd_cm" {
  metadata {
    name      = "argocd-cm"
    namespace = "argocd"
  }

  data = {
    repositories = <<EOF
    - url: git@github.com:gitsohel1030/eks-devops-gitops.git
      type: git
      sshPrivateKeySecret:
        name: argocd-ssh-creds
        key: sshPrivateKey
    EOF
  }

  depends_on = [
    kubernetes_secret_v1.argocd_ssh,
    helm_release.argocd
  ]
}