# Cloud SQL PostgreSQL Instance for Video Metadata
resource "google_sql_database_instance" "metadata_db" {
  name             = "${var.project_id}-metadata-db"
  database_version = "POSTGRES_15"
  region           = var.region
  deletion_protection = false

  depends_on = [var.api_dependencies, var.service_networking_connection]

  settings {
    tier              = "db-f1-micro"
    availability_type = "REGIONAL"
    
    backup_configuration {
      enabled            = true
      point_in_time_recovery_enabled = true
      backup_retention_settings {
        retained_backups = 30
        retention_unit   = "COUNT"
      }
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = var.vpc_id
    }

    user_labels = {
      environment = "production"
      purpose     = "video-metadata"
    }
  }
}

# Cloud SQL Database
resource "google_sql_database" "metadata" {
  name     = "video_metadata"
  instance = google_sql_database_instance.metadata_db.name
  charset  = "UTF8"
}

# Cloud SQL Database User with IAM authentication (for Cloud Run service account)
resource "google_sql_user" "cloud_run_user" {
  name     = split("@", var.cloud_run_sa_email)[0]
  instance = google_sql_database_instance.metadata_db.name
  type     = "CLOUD_IAM_SERVICE_ACCOUNT"
}

# Cloud SQL Database User (password-based authentication)
resource "google_sql_user" "app_user" {
  name     = "app_user"
  instance = google_sql_database_instance.metadata_db.name
  password = var.db_password
  type     = "BUILT_IN"
}

# Cloud SQL Auth proxy service account
resource "google_service_account" "cloud_sql_proxy" {
  account_id   = "cloud-sql-proxy"
  display_name = "Cloud SQL Auth Proxy"
  project      = var.project_id
}

# Cloud SQL Auth proxy IAM roles
resource "google_project_iam_member" "cloud_sql_proxy_role" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.cloud_sql_proxy.email}"
}
