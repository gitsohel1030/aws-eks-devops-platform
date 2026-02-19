resource "helm_release" "alb_controller" {
  name = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart = "aws-load-balancer-controller"
  namespace = "kube-system"

  set = [ {
    name = "clusterName"
    value = module.eks.cluster_name
  },

  {
    name = "region"
    value = var.region
  }   ,

  {
    name = "vpcId"
    value = module.vpc.vpc_id
  },

  {
    name = "serviceAccount.create"
    value = "true"
  },

  {
    name = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  },

  {
    name = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.alb_controller.arn
  }
  
  ]
}