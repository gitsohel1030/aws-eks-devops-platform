###########################################
# LOAD SSH KEY FROM SSM (Secure)
###########################################

data "aws_ssm_parameter" "ssh_private_key" {
  name = "/gitops/ssh_private_key"
}

###########################################
# CREATE ARGOCD SSH SECRET
###########################################

resource "kubernetes_secret_v1" "argocd_ssh" {
  metadata {
    name      = "argocd-ssh-creds"
    namespace = "argocd"
  }

  data = {
    sshPrivateKey = base64encode(data.aws_ssm_parameter.ssh_private_key.value)
  }

  type = "Opaque"
  
}