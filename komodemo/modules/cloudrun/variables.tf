variable "project_id" { type = string }
variable "region" { type = string }
variable "image" { type = string }
variable "service_name" { type = string }

variable "bucket_name" {
  type        = string
  description = "Name of the GCS bucket (optional)"
  default     = null
}

variable "vpc_connector_name" {
  type        = string
  description = "VPC Connector name for private network access"
}

variable "api_gateway_sa_email" {
  type        = string
  description = "API Gateway service account email"
}

variable "storage_encryption_key" {
  type        = string
  description = "KMS key for storage encryption"
}

variable "min_instances" {
  type        = number
  default     = 1
  description = "Minimum number of Cloud Run instances"
}

variable "max_instances" {
  type        = number
  default     = 10
  description = "Maximum number of Cloud Run instances (limited to 10 per 2 CPU allocation)"
}

variable "enable_iap" {
  type        = bool
  default     = false
  description = "Enable Identity-Aware Proxy for Cloud Run service"
}