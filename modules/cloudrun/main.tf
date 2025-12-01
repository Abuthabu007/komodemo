#Create Service Account for Cloud Run

resource "google_service_account" "run_sa" {
  account_id   = "${lower(var.service_name)}-sa"   # Example: video-processor-sa
  display_name = "Service account for Cloud Run ${var.service_name}"
  project      = var.project_id
}

# give the SA permission to access storage
resource "google_project_iam_member" "sa_storage_admin" {
project = var.project_id
role = "roles/storage.objectAdmin"
member = "serviceAccount:${google_service_account.run_sa.email}"
}


# Cloud Run (v2)
resource "google_cloud_run_v2_service" "Playvideo" {
name = var.service_name
location = var.region
project = var.project_id
deletion_protection = false

template {
service_account = google_service_account.run_sa.email


containers {
image = var.image
ports {
container_port = 8080
}
env {
name = "BUCKET_NAME"
value = var.bucket_name
}
}
}


traffic {
type = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
percent = 100

}
}


# Allow unauthenticated invocations for testing (remove or restrict in prod)
resource "google_cloud_run_service_iam_member" "invoker" {
location = var.region
project = var.project_id
service = google_cloud_run_v2_service.Playvideo.name
role = "roles/run.invoker"
member = "allUsers"
}
