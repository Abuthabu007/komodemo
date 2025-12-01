#Create Service Account for Cloud Run

resource "google_service_account" "run_sa" {
  account_id   = "${lower(var.service_name)}-sa"   # Example: video-processor-sa
  display_name = "Service account for Cloud Run ${var.service_name}"
  project      = var.project_id
}

# give the SA permission to access storage and decrypt KMS keys
resource "google_project_iam_member" "sa_storage_admin" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.run_sa.email}"
}

resource "google_project_iam_member" "sa_kms_decrypt" {
  project = var.project_id
  role    = "roles/cloudkms.cryptoKeyDecrypter"
  member  = "serviceAccount:${google_service_account.run_sa.email}"
}

resource "google_kms_crypto_key_iam_member" "cloud_run_decrypt" {
  crypto_key_id = var.storage_encryption_key
  role          = "roles/cloudkms.cryptoKeyDecrypter"
  member        = "serviceAccount:${google_service_account.run_sa.email}"
}


# Cloud Run (v2) with enterprise security
resource "google_cloud_run_v2_service" "Playvideo" {
  name       = var.service_name
  location   = var.region
  project    = var.project_id
  ingress    = "INGRESS_TRAFFIC_ALL"
  
  deletion_protection = false

  template {
    service_account = google_service_account.run_sa.email
    timeout         = "3600s"
    max_instance_request_concurrency = 10

    containers {
      image = var.image
      
      ports {
        container_port = 8080
        name           = "http1"
      }

      resources {
        limits = {
          cpu    = "2"
          memory = "2Gi"
        }
      }

      env {
        name  = "BUCKET_NAME"
        value = var.bucket_name
      }

      env {
        name  = "LOG_LEVEL"
        value = "INFO"
      }

      liveness_probe {
        http_get {
          path = "/health"
          port = 8080
        }
        initial_delay_seconds = 10
        timeout_seconds       = 3
        period_seconds        = 10
        failure_threshold     = 3
      }

      startup_probe {
        http_get {
          path = "/health"
          port = 8080
        }
        initial_delay_seconds = 0
        timeout_seconds       = 3
        period_seconds        = 3
        failure_threshold     = 5
      }
    }

    # VPC connector disabled - using default ingress with internal-only traffic
    # VPC Connector "vpc-connector" already exists in the project and will be configured manually post-deployment
    # To re-enable: uncomment below and ensure connector exists in projects/PROJECT_ID/locations/REGION/connectors/vpc-connector
    # vpc_access {
    #   connector = "projects/${var.project_id}/locations/${var.region}/connectors/${var.vpc_connector_name}"
    #   egress    = "PRIVATE_RANGES_ONLY"
    # }

    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  depends_on = [google_service_account.run_sa]
}


# Cloud Run IAM - Restrict to authenticated users only


# Cloud Run IAM - API Gateway specific access
resource "google_cloud_run_service_iam_member" "api_gateway_invoker" {
  location = google_cloud_run_v2_service.Playvideo.location
  service  = google_cloud_run_v2_service.Playvideo.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${var.api_gateway_sa_email}"

  depends_on = [google_cloud_run_v2_service.Playvideo]
}
