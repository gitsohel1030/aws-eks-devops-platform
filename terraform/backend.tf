terraform {
  backend "s3" {
    bucket = "sohel-eks-terraform-state-1030"
    key    = "envs/prod/terraform.tfstate"
    region = "ap-south-1"
    # dynamodb_table = "eks-locks"
    use_lockfile = true
    encrypt      = true

  }
}