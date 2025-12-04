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
  # Add valid Google account emails or groups that exist in your organization
  # Examples:
  # "user:ahamedbeema1988@gmail.com",           # Individual Google account
  # "group:developers@yourdomain.com",          # Google Workspace group
  # "serviceAccount:service@project.iam.gserviceaccount.com"  # Service account
]