variable "project_id" { type = string }
variable "region" { type = string }
variable "bucket_name" { type = string }

variable "kms_key" {
  type        = string
  description = "KMS key for encryption"
}

variable "project_number" {
  type        = string
  description = "GCP project number"
}

variable "video_processor_sa_email" {
  type        = string
  description = "Video processor service account email"
}

variable "cors_origins" {
  type        = list(string)
  description = "CORS allowed origins"
  default     = ["https://yourdomain.com"]
}
