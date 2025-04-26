# NGFK Directus

## Manual setup

### Google Cloud Platform

Most of the Google Cloud Platform infrastructure is deployed using Terraform. To get Terraform to work properly from GitHub Actions these steps were taken.

1. Create GCP project
   - Project ID: `ngfk-directus-458008`
1. Add a bucket for Terraform's state
   - Bucket name: `ngfk-directus-458008-tf-state`
   - Location type: `Region`
   - Location: `europe-west4`
1. Create a service-account for GitHub Actions
   - Account name: `GitHub Actions`
   - Account ID: `github-actions`
   - Email: `github-actions@ngfk-directus-458008.iam.gserviceaccount.com`
   - Role: `Owner`
1. Setup Workload Identity Federation (WIF)
   - Pool name: `GitHub`
   - Pool ID: `github`
   - Provider: `OpenID Connect (OIDC)`
   - Provider name: `GitHub Actions`
   - Provider ID: `github-actions`
   - Issuer: `https://token.actions.githubusercontent.com`
   - Attribute `google.subject`: `assertion.sub`
   - Attribute `attribute.repository`: `assertion.repository`
   - Attribute conditions: `attribute.repository=="ngfk-development/ngfk-directus"`
1. Grant service-account access to WIF
   - Filter: `repository` = `ngfk-development/ngfk-directus`
