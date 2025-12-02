# Video Platform - Cloud Run Deployment Guide

## Overview

This is a production-grade video platform built on Google Cloud Platform with the following components:

- **Cloud Run v2** - Serverless video processing application
- **Cloud SQL PostgreSQL** - Metadata and audit logging database
- **Cloud Storage** - Video file storage with versioning
- **Pub/Sub** - Event-driven transcoding pipeline
- **Vertex AI Search** - Video discovery and metadata indexing

## Architecture

```
User Upload
    ↓
Cloud Run (Flask App)
    ↓
Cloud Storage (GCS) + Cloud SQL (Metadata)
    ↓
Pub/Sub Topic (Transcoding Event)
    ↓
Video Processing Service
    ↓
Update Metadata → Vertex AI Search Index
```

## Prerequisites

1. GCP project with billing enabled
2. gcloud CLI installed and authenticated
3. Docker installed (for local testing)
4. PostgreSQL client tools (psql) for database initialization

## Environment Setup

### 1. Configure Cloud SQL

```bash
# Connect to Cloud SQL instance
gcloud sql connect komo-infra-479911-metadata-db \
  --project=komo-infra-479911 \
  --user=app_user

# Run initialization script
psql -h <CLOUD_SQL_PRIVATE_IP> \
  -U app_user \
  -d video_metadata \
  -f sql/init.sql
```

### 2. Build Docker Image

```bash
cd app
docker build -t gcr.io/komo-infra-479911/video-processor:latest .
```

### 3. Push to Artifact Registry

```bash
docker push gcr.io/komo-infra-479911/video-processor:latest
```

### 4. Deploy to Cloud Run

```bash
gcloud run deploy video-processor \
  --image gcr.io/komo-infra-479911/video-processor:latest \
  --platform managed \
  --region us-central1 \
  --set-env-vars \
    CLOUD_SQL_INSTANCE=komo-infra-479911:us-central1:komo-infra-479911-metadata-db,\
    DB_USER=app_user,\
    DB_PASSWORD=$(gcloud secret versions access latest --secret=db-password),\
    DB_NAME=video_metadata,\
    GCP_PROJECT_ID=komo-infra-479911,\
    BUCKET_NAME=play-video-upload-01,\
    LOG_LEVEL=INFO \
  --service-account video-processor@komo-infra-479911.iam.gserviceaccount.com \
  --memory 2Gi \
  --cpu 2 \
  --timeout 3600 \
  --max-instances 100
```

## API Endpoints

### Health Check
```bash
curl -X GET https://video-processor-xxxx.a.run.app/health
```

### Upload Video
```bash
curl -X POST https://video-processor-xxxx.a.run.app/upload \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -F "file=@video.mp4" \
  -F "user_id=user123" \
  -F "visibility=private" \
  -F "allow_download=true"
```

Response:
```json
{
  "success": true,
  "video_id": "550e8400-e29b-41d4-a716-446655440000",
  "gcs_path": "uploads/user123/550e8400.../video.mp4",
  "message": "Video uploaded successfully. Processing started."
}
```

### Get Video Metadata
```bash
curl -X GET https://video-processor-xxxx.a.run.app/metadata/550e8400-e29b-41d4-a716-446655440000 \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### Update Video Metadata
```bash
curl -X PUT https://video-processor-xxxx.a.run.app/metadata/550e8400-e29b-41d4-a716-446655440000 \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "visibility": "public",
    "download_allowed": true,
    "transcoding_status": "completed"
  }'
```

### List User Videos
```bash
curl -X GET "https://video-processor-xxxx.a.run.app/videos/user123?visibility=private" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### Search Videos
```bash
curl -X GET "https://video-processor-xxxx.a.run.app/search?q=tutorial&status=ready" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### Get Audit Logs
```bash
curl -X GET "https://video-processor-xxxx.a.run.app/audit-log?video_id=550e8400-e29b-41d4-a716-446655440000" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

## Database Initialization

The `sql/init.sql` script creates:

### Tables
- `video_metadata` - Video upload and transcoding information
- `audit_log` - All operations for compliance

### Functions
- `get_user_videos()` - Retrieve user's videos with pagination
- `search_videos()` - Full-text search on videos
- `update_transcoding_status()` - Update transcoding progress
- `get_video_for_playback()` - Authorization-aware video retrieval
- `delete_video_metadata()` - Soft delete videos
- `log_audit_event()` - Audit trail logging

### Views (Analytics)
- `v_daily_uploads` - Daily upload statistics
- `v_transcoding_status` - Transcoding status summary
- `v_storage_usage_by_user` - Storage usage by user

### Triggers
- `trigger_update_video_metadata` - Auto-update timestamps
- `trigger_log_video_upload` - Audit log on upload

## Vertex AI Search Configuration

### 1. Create Data Store (Manual)

```bash
gcloud discovery-engine data-stores create \
  --location=us-central1 \
  --display-name="Video Metadata Store" \
  --data-store-id=komo-infra-479911-video-metadata-store \
  --solution-types=SOLUTION_TYPE_SEARCH \
  --industry-vertical=MEDIA
```

### 2. Create Search Engine

```bash
gcloud discovery-engine search-engines create \
  --location=us-central1 \
  --display-name="Video Search Engine" \
  --engine-id=komo-infra-479911-video-search-engine \
  --data-store-ids=komo-infra-479911-video-metadata-store \
  --solution-type=SOLUTION_TYPE_SEARCH
```

### 3. Index Metadata

Connect Cloud SQL to Vertex AI Search for real-time indexing:

```bash
# Create connector configuration
gcloud discovery-engine indices create \
  --location=us-central1 \
  --engine-id=komo-infra-479911-video-search-engine \
  --data-store-id=komo-infra-479911-video-metadata-store \
  --documents-ds-import-data-source-type=CLOUD_SQL \
  --documents-ds-import-data-source-cloud-sql-uri=postgresql://app_user@/cloudsql/komo-infra-479911:us-central1:komo-infra-479911-metadata-db/video_metadata
```

## Security Considerations

### Authentication
- All endpoints require Authorization header
- Implement OAuth 2.0 / Service Account auth in production

### Database
- Passwords stored in Secret Manager
- Cloud SQL Auth proxy for secure connections
- IAM-based authentication preferred

### Cloud Storage
- Uniform bucket-level access
- Signed URLs for file downloads
- Audit logging enabled

### Network
- Private IP for Cloud SQL
- VPC isolation for services
- Firewall rules restrict traffic

## Monitoring and Logging

### View Logs
```bash
gcloud logging read "resource.type=cloud_run_revision" \
  --limit 50 \
  --project komo-infra-479911
```

### Monitor Cloud SQL
```bash
gcloud sql operations list \
  --instance=komo-infra-479911-metadata-db \
  --project=komo-infra-479911
```

### Check Cloud Run Metrics
```bash
gcloud monitoring metrics-descriptors list \
  --filter="metric.type:cloudrun*"
```

## Troubleshooting

### Database Connection Issues
```sql
-- Check connections
SELECT count(*) FROM pg_stat_activity;

-- Check database size
SELECT pg_database.datname, pg_size_pretty(pg_database_size(pg_database.datname)) 
FROM pg_database;
```

### Cloud Run Logs
```bash
gcloud run services describe video-processor \
  --region us-central1 \
  --project komo-infra-479911
```

### Cloud SQL Private IP Connectivity
```bash
gcloud sql instances describe komo-infra-479911-metadata-db \
  --project=komo-infra-479911 | grep ipAddresses -A 5
```

## Performance Optimization

### Connection Pooling
- SimpleConnectionPool: 1-20 connections
- Adjust based on expected concurrency

### Database Indexes
- Predefined on common query patterns
- Monitor with `EXPLAIN ANALYZE`

### Cloud Run Scaling
- Min instances: 1
- Max instances: 100
- Memory: 2 GB
- CPU: 2 cores

## Cost Optimization

1. **Cloud SQL**: Use db-f1-micro for development, db-n1-standard for production
2. **Cloud Run**: Set memory/CPU appropriate to workload
3. **Cloud Storage**: Enable lifecycle policies for old videos
4. **Vertex AI Search**: Regional deployments only when needed

## Next Steps

1. Implement authentication middleware (OAuth 2.0, Service Accounts)
2. Add video transcoding service (using Eventarc + Cloud Tasks)
3. Deploy Vertex AI Search indexing pipeline
4. Set up CI/CD with Cloud Build
5. Configure alerting and monitoring dashboards

## Support

For issues or questions:
1. Check Cloud Run logs: `gcloud logging read`
2. Verify Cloud SQL connectivity
3. Review Terraform outputs for resource details
