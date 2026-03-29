# ── S3 Bucket for Loki Log Storage ──────────────────────────
resource "aws_s3_bucket" "loki" {
  bucket        = "${var.cluster_name}-loki-logs"
  force_destroy = true   # empties bucket automatically on terraform destroy
 
  tags = {
    Environment = "prod"
    Terraform   = "true"
    Purpose     = "loki-log-storage"
  }
}
 
# Block all public access — logs should never be public
resource "aws_s3_bucket_public_access_block" "loki" {
  bucket = aws_s3_bucket.loki.id
 
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
 
# Enable versioning — protects against accidental log deletion
resource "aws_s3_bucket_versioning" "loki" {
  bucket = aws_s3_bucket.loki.id
 
  versioning_configuration {
    status = "Enabled"
  }
}
 
# Lifecycle rule — automatically delete logs older than 30 days
# Keeps storage costs minimal on a portfolio cluster
resource "aws_s3_bucket_lifecycle_configuration" "loki" {
  bucket = aws_s3_bucket.loki.id
 
  rule {
    id     = "expire-old-logs"
    status = "Enabled"

    #empty filter to apply rules all objects in bucket
    filter {}
 
    expiration {
      days = 30
    }
 
    # Also clean up incomplete multipart uploads
    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}
 
# ── IAM Policy for Loki ──────────────────────────────────────
# Defines exactly what S3 actions Loki is allowed to do
# Principle of least privilege — nothing more than what's needed
resource "aws_iam_policy" "loki" {
  name        = "${var.cluster_name}-loki-s3-policy"
  description = "Allows Loki to read/write logs to S3"
 
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",        # write log chunks
          "s3:GetObject",        # read log chunks for queries
          "s3:DeleteObject",     # delete expired chunks
          "s3:ListBucket",       # list chunks in bucket
          "s3:GetBucketLocation" # required for multipart uploads
        ]
        Resource = [
          aws_s3_bucket.loki.arn,
          "${aws_s3_bucket.loki.arn}/*"
        ]
      }
    ]
  })
}
 
# ── IRSA Role for Loki ───────────────────────────────────────
# Maps Loki's Kubernetes ServiceAccount to this IAM role
# Loki pods get AWS credentials automatically — no hardcoded keys
module "loki_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"
 
  role_name = "${var.cluster_name}-loki"
 
  # Don't use a managed policy here — attach our custom one below
  role_policy_arns = {
    loki = aws_iam_policy.loki.arn
  }
 
  oidc_providers = {
    main = {
      provider_arn = module.eks.oidc_provider_arn
 
      # loki is the ServiceAccount name the Loki Helm chart creates
      # in the logging namespace
      namespace_service_accounts = ["logging:loki"]
    }
  }
}
 