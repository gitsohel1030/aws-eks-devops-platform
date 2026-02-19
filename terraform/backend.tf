terraform {
  backend "s3" {
    bucket         = "sohel-eks-terraform-state-8553"
    key            = "envs/dev/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "eks-locks"
    encrypt        = true

  }
}