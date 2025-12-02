output "instance_name" {
  value       = google_sql_database_instance.metadata_db.name
  description = "Cloud SQL instance name"
}

output "instance_connection_name" {
  value       = google_sql_database_instance.metadata_db.connection_name
  description = "Cloud SQL connection name for Cloud SQL Auth proxy"
}

output "private_ip" {
  value       = google_sql_database_instance.metadata_db.private_ip_address
  description = "Private IP address of Cloud SQL instance"
}

output "database_name" {
  value       = google_sql_database.metadata.name
  description = "Cloud SQL database name"
}

output "cloud_sql_proxy_sa_email" {
  value       = google_service_account.cloud_sql_proxy.email
  description = "Cloud SQL Auth proxy service account email"
}

output "app_user_name" {
  value       = google_sql_user.app_user.name
  description = "Database application user"
}
