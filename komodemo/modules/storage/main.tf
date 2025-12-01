resource "google_storage_bucket" "uploads" {
  name                        = var.bucket_name
  project                     = var.project_id
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = true

  versioning {
    enabled = true
  }

  public_access_prevention = "enforced"

  # Note: KMS encryption will be added after bucket creation to avoid chicken-and-egg dependency
  # with Cloud Storage service account which is auto-created during encryption setup

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age                = 2555
      num_newer_versions = 0
    }
  }

  logging {
    log_bucket        = google_storage_bucket.audit_logs.name
    log_object_prefix = "bucket-logs/"
  }
}

resource "google_storage_bucket" "audit_logs" {
  name                        = "${var.bucket_name}-audit-logs"
  project                     = var.project_id
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = true
  default_event_based_hold    = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }
}


# NOTE: Cloud Storage IAM bindings for Cloud Storage service account will be added manually post-deployment
# The service account is auto-created by GCP during bucket operations and not available during initial provisioning

# NOTE: Cloud Storage IAM bindings for Cloud Run service account will be added post-deployment