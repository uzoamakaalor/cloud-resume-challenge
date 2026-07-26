# Cloud Resume Challenge — AWS + Terraform

My résumé, running as a serverless web application on AWS. It is a static site with HTTPS on a custom domain, plus a visitor counter backed by Lambda and DynamoDB. Everything is provisioned with Terraform and deployed through a GitHub Actions pipeline that authenticates to AWS without any stored credentials.

**Live site: [ruthalorresume.online](https://ruthalorresume.online)**

This is the first flagship project in my Cloud and DevOps portfolio.

---

## What it does

The site itself is a single static page. The work is in everything behind it:

The page is served globally over HTTPS through a CDN, from an S3 bucket that is never publicly accessible. Only the CDN can read it.

Every visit calls a serverless API that increments a counter in a database and returns the new total, which then renders in the footer.

The entire stack, meaning every bucket, function, DNS record, and IAM policy, is defined in code. Nothing was configured by hand in the console and left undocumented.

Pushing to `main` deploys the whole thing. The pipeline applies infrastructure changes, syncs the site, and clears the CDN cache. No AWS keys are stored anywhere in the process.

---

## How a request flows

A visitor resolves `ruthalorresume.online` through Route 53, which points at CloudFront. CloudFront serves the page from the private S3 bucket using an Origin Access Control identity, so the bucket rejects all direct public access. Once the page has loaded, JavaScript calls the API Gateway endpoint, which invokes a Lambda function. That function increments the count in DynamoDB and returns it to the browser.

---

## Tech stack

| Layer | Service / Tool |
|---|---|
| Infrastructure as Code | Terraform (AWS provider `~> 5.60`) |
| Frontend hosting | S3 (private) and CloudFront |
| DNS | Route 53 (domain registered at Namecheap) |
| TLS | AWS Certificate Manager (us-east-1) |
| API | API Gateway (HTTP API v2) |
| Compute | AWS Lambda (Python 3.12, boto3) |
| Database | DynamoDB (on-demand) |
| CI/CD | GitHub Actions with OIDC |
| State | S3 backend with native locking |

The primary region is `eu-west-2` (London). The ACM certificate lives in `us-east-1` because CloudFront requires it.

---

## Key decisions

A few choices I made deliberately, and the reasoning behind them.

**Private bucket rather than public website hosting.** The S3 bucket is kept fully private, with CloudFront in front of it using an Origin Access Control. The only thing that can read the bucket is my distribution, so the site is never exposed directly to the public internet.

**OIDC rather than stored AWS keys.** The pipeline authenticates to AWS using GitHub's OIDC provider and a scoped IAM role. GitHub proves its identity on each run and receives short lived credentials, so there are no long lived access keys sitting in GitHub secrets. The trust policy is locked to this specific repository.

**Atomic counter increment.** The Lambda uses DynamoDB's `ADD` update expression instead of reading the value, changing it in code, and writing it back. This keeps the count correct even if two people load the page at the same moment, because the database performs the increment itself.

**Least privilege for the Lambda role.** The counter function's IAM role can touch exactly one DynamoDB table and write its logs, and nothing else.

**A manual approval gate on infrastructure.** The pipeline runs on every push, but the Terraform apply sits behind a GitHub Environment that requires approval before it proceeds. The whole pipeline is a single job, so there is exactly one OIDC handshake per deploy.

---

## Repository layout

```
.
├── frontend/
│   └── index.html            # the résumé (semantic HTML, hand-written CSS)
├── infra/
│   ├── versions.tf           # Terraform and provider versions, S3 backend
│   ├── providers.tf          # eu-west-2 default plus us-east-1 aliased provider
│   ├── variables.tf
│   ├── s3.tf                 # private site bucket
│   ├── cloudfront.tf         # distribution, OAC, bucket policy
│   ├── acm.tf                # certificate (us-east-1) and DNS validation
│   ├── route53.tf            # hosted zone and alias records
│   ├── dynamodb.tf           # visitor counter table
│   ├── lambda.tf             # counter function and least privilege IAM
│   ├── apigateway.tf         # HTTP API exposing the Lambda
│   └── github-oidc.tf        # OIDC provider and deploy role
├── lambda/
│   └── counter.py            # Python and boto3 counter handler
└── .github/workflows/
    └── deploy.yml            # CI/CD pipeline
```

---

## Problems I worked through

A few things I ran into, because working through them was where most of the learning happened.

**The ACM certificate has to be in us-east-1.** CloudFront only accepts certificates from `us-east-1`, no matter where the rest of the stack lives. I handled this with a second, aliased AWS provider dedicated to the certificate, while everything else stays in `eu-west-2`.

**A duplicate Route 53 hosted zone broke DNS.** DNS lookups were alternating between two different sets of nameservers, which would have silently broken certificate validation. A stray second hosted zone was the cause. Deleting it and letting the caches clear resolved the inconsistency.

**GitHub's OIDC subject claim was not the standard format.** The pipeline kept failing with `Not authorized to perform sts:AssumeRoleWithWebIdentity`, even though every part of the trust policy looked correct. I added a debug step to decode the actual token, which revealed that GitHub was sending an ID augmented subject in the form `repo:owner@<id>/repo@<id>:...` instead of the usual `repo:owner/repo:...`. The fix was a wildcard trust condition, `repo:owner*/repo*:*`, that tolerates the embedded IDs while staying scoped to the repository. The error told me what had failed but not why, so the only way through was to inspect the real token.

---

## Roadmap

This is the first of three flagship portfolio projects:

1. Cloud Resume Challenge (this project)
2. Three tier AWS architecture (console, Terraform, and boto3)
3. EKS cluster with Prometheus and Grafana monitoring

---


