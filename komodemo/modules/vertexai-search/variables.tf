variable "project_id" {
  type        = string
  description = "GCP Project ID"
}

variable "region" {
  type        = string
  description = "GCP Region"
}

variable "cloud_sql_instance_name" {
  type        = string
  description = "Cloud SQL instance name for metadata storage"
}

variable "bucket_name" {
  type        = string
  description = "GCS bucket name for video storage"
}

variable "api_dependencies" {
  type        = list(any)
  description = "API dependencies to ensure they are enabled"
}
