# ============================================================
# Route 53 hosted zone for the domain.
# Creating this gives us 4 AWS nameservers, which we then set
# at Namecheap so AWS becomes authoritative for DNS.
# ============================================================

resource "aws_route53_zone" "main" {
  name = var.domain_name   # ruthalorresume.online
}

# Output the 4 nameservers — we paste these into Namecheap
output "route53_nameservers" {
  value       = aws_route53_zone.main.name_servers
  description = "Set these 4 nameservers at Namecheap"
}

# Output the zone ID — needed by later steps (cert validation, alias records)
output "route53_zone_id" {
  value       = aws_route53_zone.main.zone_id
  description = "Hosted zone ID"
}
