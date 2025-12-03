output "vpc_id" {
  value       = google_compute_network.vpc.id
  description = "VPC Network ID"
}

output "vpc_connector_id" {
  value       = "vpc-connector"  # Existing VPC Connector - managed separately
  description = "VPC Connector name for Cloud Run"
}

output "cloud_armor_policy_name" {
  value       = "cloud-armor-policy-disabled"  # Cloud Armor disabled due to quota limit
  description = "Cloud Armor security policy name (currently disabled)"
}

output "kms_keyring_name" {
  value       = google_kms_key_ring.keyring.name
  description = "KMS Keyring name"
}

output "storage_key_name" {
  value       = google_kms_crypto_key.storage_key.id
  description = "Full KMS key path for storage encryption"
}

output "database_key_name" {
  value       = google_kms_crypto_key.database_key.id
  description = "Full KMS key path for database encryption"
}

output "service_networking_connection" {
  value       = google_service_networking_connection.cloud_sql_peering
  description = "Service networking connection for Cloud SQL private IP"
}

output "iap_brand_name" {
  value       = try(google_iap_brand.project_brand.name, "")
  description = "IAP brand resource name"
}

output "iap_client_id" {
  value       = try(google_iap_client.project_client.client_id, "")
  description = "IAP OAuth 2.0 client ID"
  sensitive   = true
}

output "iap_client_secret" {
  value       = try(google_iap_client.project_client.client_secret, "")
  description = "IAP OAuth 2.0 client secret"
  sensitive   = true
}
