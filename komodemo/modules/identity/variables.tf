variable "project_id" {
  type        = string
  description = "GCP Project ID"
}

variable "api_dependencies" {
  type        = list(string)
  description = "List of API service names to depend on"
  default     = []
}
