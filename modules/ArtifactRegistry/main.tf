
provider "google" {
  project = var.project_id
  region  = "us-central1"
}

resource "google_project_service" "artifact_registry" {
  project = var.project_id
  service = "artifactregistry.googleapis.com"
}

resource "google_artifact_registry_repository" "docker_repo" {
  project       = var.project_id
  location      = "us-central1"
  repository_id = "cloudrun-repo"
  description   = "Docker repo for Cloud Run"
  format        = "DOCKER"
}

resource "google_project_iam_member" "cloud_run_artifact_access" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${var.service_account}"
}
