project_id = "komo-infra-479911"
project_number = "868383408248"
region = "us-central1"
bucket_name = "play-video-upload-01"
cloud_run_image = "gcr.io/cloudrun/hello"
service_name = "video-processor"
cors_origins = ["https://yourdomain.com"]
db_password = "Change_This_Password_123!"
enable_iap = true
iap_users = [
  # Cloud Run service account (for internal health checks)
  "serviceAccount:video-processor-sa@komo-infra-479911.iam.gserviceaccount.com",
  
  # Individual Google account users (replace with your emails)
  "user:ahamedbeema1989@gmail.com",
  "user:amrithachand@gmail.com",
  "user:muskansharma2598@gmail.com",
  
  # Google Workspace groups (if your organization uses Workspace)
  # "group:devops-team@yourdomain.com",
  # "group:video-admins@yourdomain.com",
  
  # Other service accounts
  # "serviceAccount:ci-cd@project.iam.gserviceaccount.com",
]