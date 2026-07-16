variable "domain_name" {
  description = "Apex domain"
  type        = string
  default     = "ruthalorresume.online"
}

variable "subdomain" {
  description = "www subdomain FQDN"
  type        = string
  default     = "www.ruthalorresume.online"
}

variable "aws_region" {
  description = "Primary region for all non-ACM resources"
  type        = string
  default     = "eu-west-2"
}

variable "project_name" {
  description = "Prefix for resource names"
  type        = string
  default     = "cloud-resume"
}
