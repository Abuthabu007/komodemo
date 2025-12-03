

variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "bucket_name" {
  type = string
}

variable "cloud_run_image" {
  type = string
}

variable "service_name" {
  type    = string
  default = "video-processor"
}

variable "project_number" {
  type = string
}

variable "cors_origins" {
  type        = list(string)
  description = "CORS allowed origins for video platform"
  default     = ["https://yourdomain.com"]
}

variable "db_password" {
  type        = string
  description = "Cloud SQL database password for app_user"
  sensitive   = true
}

variable "enable_iap" {
  type        = bool
  default     = false
  description = "Enable Identity-Aware Proxy for Cloud Run service"
}
