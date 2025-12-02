variable "project_id" {
  type        = string
  description = "GCP Project ID"
}

variable "region" {
  type        = string
  description = "GCP Region"
}

variable "vpc_id" {
  type        = string
  description = "VPC Network ID for private IP"
}

variable "cloud_run_sa_email" {
  type        = string
  description = "Cloud Run service account email for IAM authentication"
}

variable "db_password" {
  type        = string
  description = "Database password for app_user"
  sensitive   = true
}

variable "api_dependencies" {
  type        = list(any)
  description = "API dependencies to ensure they are enabled"
}

variable "service_networking_connection" {
  type        = any
  description = "Service networking connection resource for VPC peering"
}
