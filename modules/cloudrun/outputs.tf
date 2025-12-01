output "service_url" { value = google_cloud_run_v2_service.Playvideo.uri }
output "service_name" { value = google_cloud_run_v2_service.Playvideo.name }
output "service_account_email" { value = google_service_account.run_sa.email }
output "location" { value = google_cloud_run_v2_service.Playvideo.location }