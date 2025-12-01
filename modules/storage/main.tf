
resource "google_storage_bucket" "uploads" {
name = var.bucket_name
project = var.project_id
location = var.region


uniform_bucket_level_access = true
force_destroy = true


website {
main_page_suffix = "index.html"
}
}


# Optional: grant Cloud Run service account the Storage Object Viewer/Creator role later via IAM