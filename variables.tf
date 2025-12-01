
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
  default = "Playvideo"
}

variable "cloud_run_service" {}
variable "cloud_run_location" {}
variable "cloud_run_service_account" {}

variable "project_number" {
  type = string
}

variable "cloud_run_service_region" { type = string }

 