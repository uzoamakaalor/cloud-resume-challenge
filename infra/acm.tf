# ============================================================
# ACM certificate — MUST be in us-east-1 for CloudFront.
# Uses the aliased provider from providers.tf.
# Covers apex + www via a Subject Alternative Name (SAN).
# ============================================================

resource "aws_acm_certificate" "cert" {
  provider          = aws.us_east_1
  domain_name       = var.domain_name              # ruthalorresume.online
  validation_method = "DNS"

  subject_alternative_names = [
    var.subdomain                                  # www.ruthalorresume.online
  ]

  lifecycle {
    create_before_destroy = true
  }
}

# Create the DNS validation records in Route 53 automatically.
# ACM tells us what records it needs; this loops over them.
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id         = aws_route53_zone.main.zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true
}

# Wait until ACM confirms the cert is validated and issued.
resource "aws_acm_certificate_validation" "cert" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

# Output the validated cert ARN — CloudFront (Step 5) needs this
output "certificate_arn" {
  value       = aws_acm_certificate_validation.cert.certificate_arn
  description = "Validated ACM certificate ARN (us-east-1)"
}
