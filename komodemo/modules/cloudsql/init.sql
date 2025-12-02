-- Create video metadata table
CREATE TABLE IF NOT EXISTS video_metadata (
  id SERIAL PRIMARY KEY,
  video_id VARCHAR(255) UNIQUE NOT NULL,
  original_filename VARCHAR(500) NOT NULL,
  upload_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  gcs_original_path VARCHAR(1000) NOT NULL,
  gcs_transcoded_paths TEXT[],
  video_duration_seconds NUMERIC,
  resolution VARCHAR(50),
  format VARCHAR(50),
  file_size_bytes BIGINT,
  status VARCHAR(50) DEFAULT 'uploaded',
  transcoding_status VARCHAR(50) DEFAULT 'pending',
  transcoding_timestamp TIMESTAMP,
  visibility VARCHAR(20) DEFAULT 'private',
  owner_user_id VARCHAR(255) NOT NULL,
  download_allowed BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_owner_user_id ON video_metadata(owner_user_id);
CREATE INDEX IF NOT EXISTS idx_video_id ON video_metadata(video_id);
CREATE INDEX IF NOT EXISTS idx_visibility ON video_metadata(visibility);
CREATE INDEX IF NOT EXISTS idx_created_at ON video_metadata(created_at);
CREATE INDEX IF NOT EXISTS idx_status ON video_metadata(status);

-- Create audit logging table
CREATE TABLE IF NOT EXISTS audit_log (
  id SERIAL PRIMARY KEY,
  event_type VARCHAR(100) NOT NULL,
  video_id VARCHAR(255),
  user_id VARCHAR(255),
  action VARCHAR(200) NOT NULL,
  timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  details JSONB
);

-- Create indexes for audit log
CREATE INDEX IF NOT EXISTS idx_audit_video_id ON audit_log(video_id);
CREATE INDEX IF NOT EXISTS idx_audit_user_id ON audit_log(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_timestamp ON audit_log(timestamp);
