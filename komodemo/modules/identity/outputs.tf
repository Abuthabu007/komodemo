output "super_admin_role_name" {
  value = google_project_iam_custom_role.super_admin.name
}

output "video_editor_role_name" {
  value = google_project_iam_custom_role.video_editor.name
}

output "video_viewer_role_name" {
  value = google_project_iam_custom_role.video_viewer.name
}

output "api_gateway_sa_email" {
  value = google_service_account.api_gateway_sa.email
}

output "video_processor_sa_email" {
  value = google_service_account.video_processor_sa.email
}

output "analytics_sa_email" {
  value = google_service_account.analytics_sa.email
}

output "workload_identity_pool_name" {
  value = google_iam_workload_identity_pool.video_platform_pool.name
}
