output "data_store_id" {
  value       = "vertex-ai-search-to-be-configured"
  description = "Vertex AI Search data store ID (configure in GCP Console)"
}

output "vertex_ai_service_account" {
  value       = google_service_account.vertex_ai_search.email
  description = "Vertex AI service account email"
}
