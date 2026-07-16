# Default connection — everything lives in London (eu-west-2)
provider "aws" {
  region = "eu-west-2"

  default_tags {
    tags = {
      Project   = "cloud-resume-challenge"
      ManagedBy = "terraform"
      Domain    = "ruthalorresume.online"
    }
  }
}

# Second connection — Virginia (us-east-1), used ONLY for the ACM
# certificate, which CloudFront requires to be in us-east-1.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Project   = "cloud-resume-challenge"
      ManagedBy = "terraform"
      Domain    = "ruthalorresume.online"
    }
  }
}
