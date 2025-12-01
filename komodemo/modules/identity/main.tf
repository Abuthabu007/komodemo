# Custom IAM roles for video platform

# Super Admin Role
resource "google_project_iam_custom_role" "super_admin" {
  role_id     = "videoplatform_super_admin"
  title       = "Video Platform Super Admin"
  description = "Full access to video platform"
  project     = var.project_id

  permissions = [
    "storage.buckets.get",
    "storage.objects.get",
    "storage.objects.create",
    "storage.objects.delete",
    "storage.objects.update",
    "iam.roles.get",
    "iam.roles.list",
    "resourcemanager.projects.get",
    "logging.logEntries.list",
    "compute.instances.get",
    "run.services.get",
    "run.services.list",
  ]
}

# Video Editor Role
resource "google_project_iam_custom_role" "video_editor" {
  role_id     = "videoplatform_video_editor"
  title       = "Video Editor"
  description = "Can upload, edit, and manage videos"
  project     = var.project_id

  permissions = [
    "storage.objects.create",
    "storage.objects.get",
    "storage.objects.update",
    "storage.objects.delete",
  ]
}

# Video Viewer Role
resource "google_project_iam_custom_role" "video_viewer" {
  role_id     = "videoplatform_video_viewer"
  title       = "Video Viewer"
  description = "Can view and download public videos"
  project     = var.project_id

  permissions = [
    "storage.objects.get",
    "storage.buckets.get",
  ]
}

# Service Account for API Gateway (authentication)
resource "google_service_account" "api_gateway_sa" {
  account_id   = "api-gateway"
  display_name = "API Gateway Service Account"
  project      = var.project_id
  description  = "Service account for API Gateway and user authentication"
}

# Service Account for Video Processing
resource "google_service_account" "video_processor_sa" {
  account_id   = "video-processor"
  display_name = "Video Processor Service Account"
  project      = var.project_id
  description  = "Service account for video processing and transcoding"
}

# Service Account for Data Analytics
resource "google_service_account" "analytics_sa" {
  account_id   = "analytics"
  display_name = "Analytics Service Account"
  project      = var.project_id
  description  = "Service account for collecting analytics and metrics"
}

# Grant permissions to API Gateway SA
resource "google_project_iam_member" "api_gateway_storage_access" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.api_gateway_sa.email}"
}

resource "google_project_iam_member" "api_gateway_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.api_gateway_sa.email}"
}

# Grant permissions to Video Processor SA
resource "google_project_iam_member" "video_processor_storage" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.video_processor_sa.email}"
}

resource "google_project_iam_member" "video_processor_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.video_processor_sa.email}"
}

# Grant permissions to Analytics SA
resource "google_project_iam_member" "analytics_logging" {
  project = var.project_id
  role    = "roles/logging.viewer"
  member  = "serviceAccount:${google_service_account.analytics_sa.email}"
}

resource "google_project_iam_member" "analytics_bigquery" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.analytics_sa.email}"
}

# Service Account Key Rotation Policy
resource "google_service_account_key" "api_gateway_key" {
  service_account_id = google_service_account.api_gateway_sa.name
  public_key_type    = "TYPE_X509_PEM_FILE"
  lifecycle {
    create_before_destroy = true
  }
}

# Workload Identity Pool for external authentication
resource "google_iam_workload_identity_pool" "video_platform_pool" {
  workload_identity_pool_id = "${var.project_id}-pool"
  project                   = var.project_id
  display_name              = "Video Platform Pool"
}

# Workload Identity Provider for OAuth2
resource "google_iam_workload_identity_pool_provider" "video_platform_provider" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.video_platform_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = "${var.project_id}-provider"
  project                            = var.project_id

  attribute_mapping = {
    "google.subject"  = "assertion.sub"
    "attribute.email" = "assertion.email"
    "attribute.iss"   = "assertion.iss"
  }

  oidc {
    issuer_uri = "https://accounts.google.com"
  }
}
