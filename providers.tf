provider "google" {
project = var.project_id
region = var.region
}


provider "google-beta" {
project = var.project_id
region = var.region
}

# Enable required GCP APIs
resource "google_project_service" "enabled_apis" {
  for_each = toset([
    "run.googleapis.com",
    "storage.googleapis.com",
    "eventarc.googleapis.com",
    "pubsub.googleapis.com",
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "artifactregistry.googleapis.com",
    "eventarc.googleapis.com"
  ])

  service = each.value
  project = var.project_id

  disable_on_destroy = false  # Keeps APIs enabled even if infrastructure is destroyed
} 


