output "loki_s3_bucket_name" {
  value = aws_s3_bucket.loki.id
}
 
output "loki_irsa_role_arn" {
  value = module.loki_irsa_role.iam_role_arn
}
 
output "github_actions_role_arn" {
  value = aws_iam_role.github_actions.arn
}