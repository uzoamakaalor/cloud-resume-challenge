# ============================================================
# S3 bucket that stores the website files.
# Kept fully PRIVATE — only CloudFront reads from it (Step 5).
# ============================================================

resource "aws_s3_bucket" "site" {
  bucket = "${var.project_name}-site-${var.domain_name}"
  # e.g. cloud-resume-site-ruthalorresume.online
}

# Make bucket-owner the owner of all objects (predictable permissions)
resource "aws_s3_bucket_ownership_controls" "site" {
  bucket = aws_s3_bucket.site.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Block ALL public access — the site is served via CloudFront, not directly
resource "aws_s3_bucket_public_access_block" "site" {
  bucket = aws_s3_bucket.site.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning so overwritten files can be recovered
resource "aws_s3_bucket_versioning" "site" {
  bucket = aws_s3_bucket.site.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Upload index.html into the bucket
resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.site.id
  key          = "index.html"
  source       = "${path.module}/../frontend/index.html"
  content_type = "text/html"
  etag         = filemd5("${path.module}/../frontend/index.html")
}

# Output the bucket name so we can reference it later
output "site_bucket_name" {
  value       = aws_s3_bucket.site.id
  description = "Name of the S3 bucket serving the site"
}
