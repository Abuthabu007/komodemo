variable "project_id" {
  type        = string
  description = "GCP Project ID"
}

variable "project_number" {
  type        = string
  description = "GCP Project Number"
}

variable "region" {
  type        = string
  description = "GCP region"
  default     = "us-central1"
}

variable "private_subnet_cidr" {
  type        = string
  description = "CIDR range for private subnet"
  default     = "10.0.1.0/24"
}

variable "vpc_connector_cidr" {
  type        = string
  description = "CIDR range for VPC Connector"
  default     = "10.8.0.0/28"
}

variable "api_dependencies" {
  type        = list(string)
  description = "List of API service names to depend on"
  default     = []
}

variable "admin_email" {
  type        = string
  description = "Admin email for IAP brand support contact"
  default     = ""
}
