output "data_store_id" {
  value       = google_discovery_engine_data_store.video_metadata.id
  description = "Vertex AI Search data store ID"
}

output "search_engine_id" {
  value       = google_discovery_engine_search_engine.video_search.id
  description = "Vertex AI Search engine ID"
}

output "vertex_ai_service_account" {
  value       = google_service_account.vertex_ai_search.email
  description = "Vertex AI service account email"
}
