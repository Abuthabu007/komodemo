# Eventarc trigger (creates the managed service account automatically)
resource "google_pubsub_topic" "event_topic" {
  name    = "eventarc-topic-${var.bucket_name}"
  project = var.project_id
}

resource "google_eventarc_trigger" "uploadvideo" {
  name     = "my-trigger"
  location = var.region
  project  = var.project_id

  matching_criteria {
    attribute = "type"
    value     = "google.cloud.pubsub.topic.v1.messagePublished"
  }

  destination {
    cloud_run_service {
      service = var.cloud_run_service_name
      region  = var.cloud_run_service_region
    }
  }
}

# IAM binding for the Eventarc service account
resource "google_project_iam_member" "eventarc_pubsub_publisher" {
  project = var.project_id
  role    = "roles/pubsub.publisher"

  # Use project number, not project_id
  member  = "serviceAccount:service-${var.project_number}@gcp-sa-eventarc.iam.gserviceaccount.com"

  # Ensure the trigger is created first (so the service account exists)
  depends_on = [
    google_eventarc_trigger.uploadvideo
  ]
}