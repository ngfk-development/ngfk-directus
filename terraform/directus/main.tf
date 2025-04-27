terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.30.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 6.30.0"
    }
  }
}

data "google_project" "project" {}

resource "google_project_service" "run" {
  service = "run.googleapis.com"
}

resource "google_project_service" "secretmanager" {
  service = "secretmanager.googleapis.com"
}

resource "google_storage_bucket" "directus_uploads" {
  name                        = var.storage_bucket
  location                    = var.location
  force_destroy               = true
  uniform_bucket_level_access = true
}

module "secret_database_pass" {
  source      = "../secret"
  secret_id   = "DATABASE_PASS"
  secret_data = var.database_pass
  region      = var.region
}

module "secret_directus_secret" {
  source      = "../secret"
  secret_id   = "DIRECTUS_SECRET"
  secret_data = var.directus_secret
  region      = var.region
}

module "secret_google_client_secret" {
  source      = "../secret"
  secret_id   = "GOOGLE_CLIENT_SECRET"
  secret_data = var.google_client_secret
  region      = var.region
}

module "secret_smtp_password" {
  source      = "../secret"
  secret_id   = "SMTP_PASSWORD"
  secret_data = var.smtp_pass
  region      = var.region
}

resource "google_secret_manager_secret_iam_member" "database_password" {
  depends_on = [module.secret_database_pass]
  secret_id  = "DATABASE_PASS"
  role       = "roles/secretmanager.secretAccessor"
  member     = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com"
}

resource "google_secret_manager_secret_iam_member" "directus_secret" {
  depends_on = [module.secret_directus_secret]
  secret_id  = "DIRECTUS_SECRET"
  role       = "roles/secretmanager.secretAccessor"
  member     = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com"
}

resource "google_secret_manager_secret_iam_member" "google_client_secret" {
  depends_on = [module.secret_google_client_secret]
  secret_id  = "GOOGLE_CLIENT_SECRET"
  role       = "roles/secretmanager.secretAccessor"
  member     = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com"
}

resource "google_secret_manager_secret_iam_member" "smtp_password" {
  depends_on = [module.secret_smtp_password]
  secret_id  = "SMTP_PASSWORD"
  role       = "roles/secretmanager.secretAccessor"
  member     = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com"
}

resource "google_cloud_run_v2_service" "directus" {
  depends_on = [
    google_project_service.run,
    google_project_service.secretmanager,
    google_secret_manager_secret_iam_member.database_password,
    google_secret_manager_secret_iam_member.directus_secret,
    google_secret_manager_secret_iam_member.google_client_secret,
    google_secret_manager_secret_iam_member.smtp_password
  ]

  name     = "directus"
  location = var.location
  ingress  = "INGRESS_TRAFFIC_ALL"

  deletion_protection = false

  template {
    containers {
      image = var.image

      env {
        name  = "PUBLIC_URL"
        value = "https://${var.domains[0]}/"
      }

      env {
        name = "SECRET"
        value_source {
          secret_key_ref {
            secret  = "DIRECTUS_SECRET"
            version = "latest"
          }
        }
      }

      env {
        name  = "DB_CLIENT"
        value = "postgres"
      }

      env {
        name  = "DB_HOST"
        value = "/cloudsql/${var.database_connection}"
      }

      env {
        name  = "DB_PORT"
        value = var.database_port
      }

      env {
        name  = "DB_DATABASE"
        value = var.database_name
      }

      env {
        name = "DB_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = "DATABASE_PASS"
            version = "latest"
          }
        }
      }

      env {
        name  = "DB_USER"
        value = var.database_user
      }


      env {
        name  = "AUTH_PROVIDERS"
        value = "google"
      }

      env {
        name  = "AUTH_GOOGLE_DRIVER"
        value = "openid"
      }

      env {
        name  = "AUTH_GOOGLE_CLIENT_ID"
        value = var.google_client_id
      }

      env {
        name = "AUTH_GOOGLE_CLIENT_SECRET"
        value_source {
          secret_key_ref {
            secret  = "GOOGLE_CLIENT_SECRET"
            version = "latest"
          }
        }
      }

      env {
        name  = "AUTH_GOOGLE_ISSUER_URL"
        value = "https://accounts.google.com/.well-known/openid-configuration"
      }

      env {
        name  = "AUTH_GOOGLE_ALLOW_PUBLIC_REGISTRATION"
        value = "true"
      }

      env {
        name  = "AUTH_GOOGLE_IDENTIFIER_KEY"
        value = "email"
      }

      env {
        name  = "AUTH_GOOGLE_ICON"
        value = "google"
      }

      env {
        name  = "AUTH_GOOGLE_LABEL"
        value = "Google"
      }

      env {
        name  = "STORAGE_LOCATIONS"
        value = "google"
      }

      env {
        name  = "STORAGE_GOOGLE_DRIVER"
        value = "gcs"
      }

      env {
        name  = "STORAGE_GOOGLE_BUCKET"
        value = var.storage_bucket
      }

      env {
        name  = "EMAIL_FROM"
        value = var.smtp_from
      }

      env {
        name  = "EMAIL_TRANSPORT"
        value = "smtp"
      }

      env {
        name  = "EMAIL_SMTP_HOST"
        value = var.smtp_host
      }

      env {
        name  = "EMAIL_SMTP_PORT"
        value = var.smtp_port
      }

      env {
        name  = "EMAIL_SMTP_USER"
        value = var.smtp_user
      }

      env {
        name = "EMAIL_SMTP_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = "SMTP_PASSWORD"
            version = "latest"
          }
        }
      }

      env {
        name  = "EMAIL_SMTP_SECURE"
        value = "false"
      }

      env {
        name  = "CACHE_AUTO_PURGE"
        value = "true"
      }

      env {
        name  = "CONTENT_SECURITY_POLICY_DIRECTIVES__FRAME_SRC"
        value = join(" ", var.client_domains)
      }

      env {
        name  = "PRESSURE_LIMITER_ENABLED"
        value = "false"
      }

      volume_mounts {
        name       = "cloudsql"
        mount_path = "/cloudsql"
      }
    }

    scaling {
      min_instance_count = 1
      max_instance_count = 1
    }


    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = [var.database_connection]
      }
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }
}

resource "google_cloud_run_domain_mapping" "directus" {
  provider = google-beta
  for_each = toset(var.domains)
  name     = each.key
  location = var.location

  metadata {
    namespace = var.project_id
  }

  spec {
    force_override = true
    route_name     = google_cloud_run_v2_service.directus.name
  }
}

resource "google_cloud_run_v2_service_iam_binding" "public" {
  project  = var.project_id
  location = var.location
  name     = google_cloud_run_v2_service.directus.name
  role     = "roles/run.invoker"
  members  = ["allUsers"]
}
