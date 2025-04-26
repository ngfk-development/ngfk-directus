variable "project_id" {
  type = string
}

variable "image" {
  type = string
}

variable "domains" {
  type = list(string)
}

variable "directus_secret" {
  type = string
}

variable "database_name" {
  type = string
}

variable "database_user" {
  type = string
}

variable "database_pass" {
  type = string
}

variable "database_connection" {
  type = string
}

variable "database_port" {
  type = string
}

variable "location" {
  type = string
}

variable "google_client_id" {
  type = string
}

variable "google_client_secret" {
  type = string
}

variable "smtp_from" {
  type = string
}

variable "smtp_host" {
  type = string
}

variable "smtp_port" {
  type = string
}

variable "smtp_user" {
  type = string
}

variable "smtp_pass" {
  type = string
}

variable "storage_bucket" {
  type = string
}

variable "region" {
  type = string
}
