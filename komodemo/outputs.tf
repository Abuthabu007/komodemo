output "bucket_name" { 
  value = module.storage.bucket_name 
}

output "cloud_run_url" { 
  value = module.cloud_run.service_url 
}

output "eventarc_trigger_name" { 
  value = module.eventarc_trigger.trigger_name 
}

output "vpc_id" {
  value       = module.security.vpc_id
  description = "VPC Network ID"
}

output "vpc_connector_id" {
  value       = module.security.vpc_connector_id
  description = "VPC Connector for Cloud Run"
}

output "cloud_armor_policy" {
  value       = module.security.cloud_armor_policy_name
  description = "Cloud Armor security policy"
}

output "api_gateway_sa" {
  value       = module.identity.api_gateway_sa_email
  description = "API Gateway service account"
}

output "video_processor_sa" {
  value       = module.identity.video_processor_sa_email
  description = "Video Processor service account"
}

output "kms_keyring" {
  value       = module.security.kms_keyring_name
  description = "KMS Keyring for encryption"
}

output "cloud_sql_instance" {
  value       = module.cloud_sql.instance_name
  description = "Cloud SQL instance name for video metadata"
}

output "cloud_sql_connection_name" {
  value       = module.cloud_sql.instance_connection_name
  description = "Cloud SQL connection name for Cloud SQL Auth proxy"
}

output "cloud_sql_private_ip" {
  value       = module.cloud_sql.private_ip
  description = "Cloud SQL private IP address"
}

output "cloud_sql_database" {
  value       = module.cloud_sql.database_name
  description = "Cloud SQL database name"
}

output "vertex_ai_search_engine" {
  value       = module.vertex_ai_search.data_store_id
  description = "Vertex AI Search data store ID"
}

output "vertex_ai_data_store" {
  value       = module.vertex_ai_search.data_store_id
  description = "Vertex AI Search data store ID"
}
