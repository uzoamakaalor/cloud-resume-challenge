# ============================================================
# OIDC trust + IAM role allowing GitHub Actions to deploy
# to AWS WITHOUT long-lived credentials.
# ============================================================

variable "github_repo" {
  description = "GitHub repo in owner/name form"
  type        = string
  default     = "uzoamakaalor/cloud-resume-challenge"
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

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
        # GitHub sends an ID-augmented sub: repo:owner@<id>/repo@<id>:...
        # Wildcards tolerate the numeric IDs while staying repo-scoped.
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:uzoamakaalor*/cloud-resume-challenge*:*"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "github_actions_logs" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

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
