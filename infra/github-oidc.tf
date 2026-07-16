# ============================================================
# OIDC trust + IAM role allowing GitHub Actions to deploy
# to AWS WITHOUT long-lived credentials.
# ============================================================

# Your GitHub repo, in owner/repo form
variable "github_repo" {
  description = "GitHub repo in owner/name form"
  type        = string
  default     = "uzoamakaalor/cloud-resume-challenge"
}

# ---- Register GitHub as a trusted OIDC identity provider ----
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  # GitHub's OIDC thumbprint (AWS now validates via its trust store,
  # but the field is still required)
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# ---- The role GitHub Actions assumes ----
resource "aws_iam_role" "github_actions" {
  name = "${var.project_name}-github-actions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        # Lock to YOUR repo, any branch
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*"
        }
      }
    }]
  })
}

# ---- Permissions the pipeline needs ----
# Broad-ish because Terraform manages many services. Scoped to this
# project's resources where practical.
resource "aws_iam_role_policy" "github_actions" {
  name = "${var.project_name}-github-actions-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "TerraformStateAccess"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
        Resource = [
          "arn:aws:s3:::ruthalor-tfstate-7391",
          "arn:aws:s3:::ruthalor-tfstate-7391/*"
        ]
      },
      {
        Sid      = "FrontendDeploy"
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:GetObject", "s3:ListBucket", "s3:DeleteObject"]
        Resource = [
          "arn:aws:s3:::cloud-resume-site-${var.domain_name}",
          "arn:aws:s3:::cloud-resume-site-${var.domain_name}/*"
        ]
      },
      {
        Sid      = "CloudFrontInvalidate"
        Effect   = "Allow"
        Action   = ["cloudfront:CreateInvalidation", "cloudfront:GetDistribution", "cloudfront:GetInvalidation"]
        Resource = "*"
      },
      {
        Sid      = "TerraformManageResources"
        Effect   = "Allow"
        Action   = [
          "s3:*", "cloudfront:*", "acm:*", "route53:*",
          "dynamodb:*", "lambda:*", "apigateway:*",
          "iam:*", "logs:*"
        ]
        Resource = "*"
      }
    ]
  })
}

output "github_actions_role_arn" {
  value       = aws_iam_role.github_actions.arn
  description = "Role ARN to use in the GitHub Actions workflow"
}
