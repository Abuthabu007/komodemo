# Artifact Registry Repository URL
output "artifact_registry_repository_url" {
  description = "The full Artifact Registry repository URL"
  value       = google_artifact_registry_repository.docker_repo.id
}

# Repository Location
output "artifact_registry_location" {
  description = "Artifact Registry location"
  value       = google_artifact_registry_repository.docker_repo.location
}

# Repository Name
output "artifact_registry_repository_name" {
  description = "The name of the Artifact Registry repository"
  value       = google_artifact_registry_repository.docker_repo.repository_id
}

# Service Account used for Cloud Run (if passed as variable)
output "service_account_used" {
  description = "Service account used for accessing Artifact Registry"
  value       = var.service_account
}
