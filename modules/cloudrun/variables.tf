variable "project_id" { type = string }
variable "region" { type = string }
variable "image" { type = string }
variable "service_name" { type = string }

variable "bucket_name" {
  type        = string
  description = "Name of the GCS bucket (optional)"
  default     = null
}
