# Vertex AI Search configuration for video metadata discovery
resource "google_discovery_engine_data_store" "video_metadata" {
  location          = var.region
  data_store_id     = "${var.project_id}-video-metadata-store"
  display_name      = "Video Metadata Store"
  industry_vertical = "MEDIA"
  content_config    = "NO_CONTENT"
  solution_types    = ["SOLUTION_TYPE_SEARCH"]

  depends_on = [var.api_dependencies]
}

# Vertex AI Search Engine
resource "google_discovery_engine_search_engine" "video_search" {
  engine_id       = "${var.project_id}-video-search-engine"
  location        = var.region
  display_name    = "Video Search Engine"
  data_store_ids  = [google_discovery_engine_data_store.video_metadata.id]
  solution_type   = "SOLUTION_TYPE_SEARCH"
  search_engine_config {
    search_tier = "SEARCH_TIER_STANDARD"
  }
}

# Service account for Vertex AI
resource "google_service_account" "vertex_ai_search" {
  account_id   = "vertex-ai-search"
  display_name = "Vertex AI Search Service Account"
  project      = var.project_id
}

# Vertex AI Admin role
resource "google_project_iam_member" "vertex_ai_admin" {
  project = var.project_id
  role    = "roles/discoveryengine.admin"
  member  = "serviceAccount:${google_service_account.vertex_ai_search.email}"
}

# Cloud SQL Client role for Vertex AI to access metadata
resource "google_project_iam_member" "vertex_ai_sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.vertex_ai_search.email}"
}

# GCS read access for Vertex AI
resource "google_storage_bucket_iam_member" "vertex_ai_gcs_read" {
  bucket = var.bucket_name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.vertex_ai_search.email}"
}
