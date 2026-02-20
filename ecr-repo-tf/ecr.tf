resource "aws_ecr_repository" "web_app" {
  name = "web-app"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    "Environment" = "dev"
    "Terraform" = "true"
  }
}