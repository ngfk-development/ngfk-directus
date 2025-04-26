terraform {
  required_version = ">= 0.12"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.30.0"
    }
  }

  backend "gcs" {}
}

locals {
  env        = { for tuple in regexall("(.*?)=(.*)", file("../.env")) : tuple[0] => sensitive(tuple[1]) }
  project_id = var.project_id
  region     = var.region
  zone       = "${var.region}-a"

  image        = var.image
  github_image = "ghcr.io/ngfk-development/${local.image}"
  gcp_image    = "${local.region}-docker.pkg.dev/${local.project_id}/docker/${local.image}"
}

provider "google" {
  project = local.project_id
  region  = local.region
  zone    = local.zone
}

module "artifactregistry" {
  source     = "./registry"
  project_id = local.project_id
  region     = local.region
}

resource "terraform_data" "push_image" {
  depends_on       = [module.artifactregistry]
  triggers_replace = [local.github_image, local.gcp_image]

  provisioner "local-exec" {
    command = <<EOT
      docker pull ${local.github_image}
      docker tag ${local.github_image} ${local.gcp_image}
      docker push ${local.gcp_image}
    EOT
  }
}

module "database" {
  source = "./database"

  authorized_networks = [
    { name = "Home", value = "31.20.112.229" }
  ]

  database_name = local.env["DATABASE_NAME"]
  database_user = local.env["DATABASE_USER"]
  database_pass = local.env["DATABASE_PASS"]

  region = local.region
}

module "secret_env" {
  source      = "./secret"
  secret_id   = "ENV"
  secret_data = file("../.env")
  region      = local.region
}

module "directus" {
  depends_on = [terraform_data.push_image]
  source     = "./directus"

  project_id = local.project_id
  location   = local.region
  image      = local.gcp_image

  domains = [
    "cms.ngfk.dev",
    "admin.mokuminalmere.nl",
  ]

  directus_secret = local.env["DIRECTUS_SECRET"]

  database_name       = local.env["DATABASE_NAME"]
  database_user       = local.env["DATABASE_USER"]
  database_pass       = local.env["DATABASE_PASS"]
  database_connection = module.database.connection_name
  database_port       = "5432"

  google_client_id     = local.env["GOOGLE_CLIENT_ID"]
  google_client_secret = local.env["GOOGLE_CLIENT_SECRET"]

  smtp_from = "noreply@ngfk.dev"
  smtp_host = "smtp.postmarkapp.com"
  smtp_port = "587"
  smtp_user = local.env["POSTMARK_ACCESS_KEY"]
  smtp_pass = local.env["POSTMARK_SECRET_KEY"]

  storage_bucket = "${local.project_id}-directus"

  region = local.region
}
