#############################################
# READ THE ARGOCD SERVER SERVICE (DATA SOURCE)
#############################################

data "kubernetes_service_v1" "argocd_server" {
  metadata {
    name      = "argocd-server"
    namespace = "argocd"
  }
  
  depends_on = [
    helm_release.argocd
  ]

}

#############################################
# OUTPUT THE EXTERNAL LB DNS NAME
#############################################
output "argocd_server_url" {
  value = data.kubernetes_service_v1.argocd_server.status[0].load_balancer[0].ingress[0].hostname
}