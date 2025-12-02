-- Cloud SQL PostgreSQL Initialization Script
-- Video Metadata Platform Database Schema
-- Execute this script to set up the database for the video platform

-- =====================================================
-- TABLE: video_metadata
-- Purpose: Store video upload and transcoding metadata
-- =====================================================
CREATE TABLE IF NOT EXISTS video_metadata (
    id SERIAL PRIMARY KEY,
    video_id VARCHAR(255) UNIQUE NOT NULL,
    original_filename VARCHAR(500) NOT NULL,
    upload_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    gcs_original_path VARCHAR(1000) NOT NULL,
    gcs_transcoded_paths TEXT[] DEFAULT ARRAY[]::TEXT[],
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

-- Create indexes for common queries
CREATE INDEX IF NOT EXISTS idx_owner_user_id ON video_metadata(owner_user_id);
CREATE INDEX IF NOT EXISTS idx_video_id ON video_metadata(video_id);
CREATE INDEX IF NOT EXISTS idx_visibility ON video_metadata(visibility);
CREATE INDEX IF NOT EXISTS idx_created_at ON video_metadata(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_status ON video_metadata(status);
CREATE INDEX IF NOT EXISTS idx_transcoding_status ON video_metadata(transcoding_status);
CREATE INDEX IF NOT EXISTS idx_owner_visibility ON video_metadata(owner_user_id, visibility);

-- =====================================================
-- TABLE: audit_log
-- Purpose: Track all operations for compliance
-- =====================================================
CREATE TABLE IF NOT EXISTS audit_log (
    id SERIAL PRIMARY KEY,
    event_type VARCHAR(100) NOT NULL,
    video_id VARCHAR(255),
    user_id VARCHAR(255),
    action VARCHAR(200) NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    details JSONB,
    ip_address INET,
    user_agent VARCHAR(500)
);

-- Create indexes for audit queries
CREATE INDEX IF NOT EXISTS idx_audit_video_id ON audit_log(video_id);
CREATE INDEX IF NOT EXISTS idx_audit_user_id ON audit_log(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_timestamp ON audit_log(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_audit_event_type ON audit_log(event_type);

-- =====================================================
-- FUNCTION: log_audit_event
-- Purpose: Insert audit log entries
-- =====================================================
CREATE OR REPLACE FUNCTION log_audit_event(
    p_event_type VARCHAR,
    p_video_id VARCHAR,
    p_user_id VARCHAR,
    p_action VARCHAR,
    p_details JSONB DEFAULT NULL,
    p_ip_address INET DEFAULT NULL,
    p_user_agent VARCHAR DEFAULT NULL
) RETURNS void AS $$
BEGIN
    INSERT INTO audit_log (
        event_type, video_id, user_id, action,
        details, ip_address, user_agent, timestamp
    ) VALUES (
        p_event_type, p_video_id, p_user_id, p_action,
        p_details, p_ip_address, p_user_agent, CURRENT_TIMESTAMP
    );
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- FUNCTION: get_user_videos
-- Purpose: Retrieve all videos for a user with pagination
-- =====================================================
CREATE OR REPLACE FUNCTION get_user_videos(
    p_owner_id VARCHAR,
    p_visibility VARCHAR DEFAULT 'public',
    p_limit INT DEFAULT 50,
    p_offset INT DEFAULT 0
) RETURNS TABLE (
    video_id VARCHAR,
    original_filename VARCHAR,
    upload_timestamp TIMESTAMP,
    status VARCHAR,
    transcoding_status VARCHAR,
    file_size_bytes BIGINT,
    gcs_original_path VARCHAR,
    visibility VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        vm.video_id,
        vm.original_filename,
        vm.upload_timestamp,
        vm.status,
        vm.transcoding_status,
        vm.file_size_bytes,
        vm.gcs_original_path,
        vm.visibility
    FROM video_metadata vm
    WHERE vm.owner_user_id = p_owner_id
        AND (p_visibility = 'all' OR vm.visibility = p_visibility)
    ORDER BY vm.upload_timestamp DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- FUNCTION: search_videos
-- Purpose: Full-text search on video metadata
-- =====================================================
CREATE OR REPLACE FUNCTION search_videos(
    p_search_query VARCHAR,
    p_owner_id VARCHAR DEFAULT NULL,
    p_status VARCHAR DEFAULT NULL,
    p_limit INT DEFAULT 50
) RETURNS TABLE (
    video_id VARCHAR,
    original_filename VARCHAR,
    upload_timestamp TIMESTAMP,
    owner_user_id VARCHAR,
    status VARCHAR,
    transcoding_status VARCHAR,
    file_size_bytes BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        vm.video_id,
        vm.original_filename,
        vm.upload_timestamp,
        vm.owner_user_id,
        vm.status,
        vm.transcoding_status,
        vm.file_size_bytes
    FROM video_metadata vm
    WHERE vm.visibility = 'public'
        AND (p_search_query IS NULL OR vm.original_filename ILIKE '%' || p_search_query || '%')
        AND (p_owner_id IS NULL OR vm.owner_user_id = p_owner_id)
        AND (p_status IS NULL OR vm.status = p_status)
    ORDER BY vm.upload_timestamp DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- FUNCTION: update_transcoding_status
-- Purpose: Update video transcoding status and paths
-- =====================================================
CREATE OR REPLACE FUNCTION update_transcoding_status(
    p_video_id VARCHAR,
    p_status VARCHAR,
    p_transcoded_paths TEXT[] DEFAULT NULL,
    p_duration NUMERIC DEFAULT NULL,
    p_resolution VARCHAR DEFAULT NULL
) RETURNS BOOLEAN AS $$
BEGIN
    UPDATE video_metadata
    SET 
        transcoding_status = p_status,
        transcoding_timestamp = CURRENT_TIMESTAMP,
        gcs_transcoded_paths = COALESCE(p_transcoded_paths, gcs_transcoded_paths),
        video_duration_seconds = COALESCE(p_duration, video_duration_seconds),
        resolution = COALESCE(p_resolution, resolution),
        status = CASE WHEN p_status = 'completed' THEN 'ready' ELSE status END,
        updated_at = CURRENT_TIMESTAMP
    WHERE video_id = p_video_id;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- FUNCTION: get_video_for_playback
-- Purpose: Retrieve video with playback authorization checks
-- =====================================================
CREATE OR REPLACE FUNCTION get_video_for_playback(
    p_video_id VARCHAR,
    p_requester_id VARCHAR
) RETURNS TABLE (
    video_id VARCHAR,
    original_filename VARCHAR,
    gcs_original_path VARCHAR,
    gcs_transcoded_paths TEXT[],
    owner_user_id VARCHAR,
    visibility VARCHAR,
    download_allowed BOOLEAN,
    status VARCHAR,
    transcoding_status VARCHAR,
    video_duration_seconds NUMERIC,
    resolution VARCHAR
) AS $$
BEGIN
    -- Check if video exists and requester has access
    RETURN QUERY
    SELECT 
        vm.video_id,
        vm.original_filename,
        vm.gcs_original_path,
        vm.gcs_transcoded_paths,
        vm.owner_user_id,
        vm.visibility,
        vm.download_allowed,
        vm.status,
        vm.transcoding_status,
        vm.video_duration_seconds,
        vm.resolution
    FROM video_metadata vm
    WHERE vm.video_id = p_video_id
        AND (vm.visibility = 'public' 
             OR vm.owner_user_id = p_requester_id
             OR p_requester_id = 'admin');
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- FUNCTION: delete_video_metadata
-- Purpose: Soft delete video metadata
-- =====================================================
CREATE OR REPLACE FUNCTION delete_video_metadata(
    p_video_id VARCHAR,
    p_user_id VARCHAR
) RETURNS BOOLEAN AS $$
BEGIN
    UPDATE video_metadata
    SET 
        status = 'deleted',
        updated_at = CURRENT_TIMESTAMP
    WHERE video_id = p_video_id
        AND (owner_user_id = p_user_id OR p_user_id = 'admin');
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- TRIGGER: update_video_metadata_timestamp
-- Purpose: Automatically update updated_at on any change
-- =====================================================
CREATE OR REPLACE FUNCTION update_metadata_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_video_metadata ON video_metadata;
CREATE TRIGGER trigger_update_video_metadata
BEFORE UPDATE ON video_metadata
FOR EACH ROW
EXECUTE FUNCTION update_metadata_timestamp();

-- =====================================================
-- TRIGGER: log_video_upload
-- Purpose: Audit log video uploads
-- =====================================================
DROP TRIGGER IF EXISTS trigger_log_video_upload ON video_metadata;
CREATE TRIGGER trigger_log_video_upload
AFTER INSERT ON video_metadata
FOR EACH ROW
EXECUTE FUNCTION log_audit_event(
    'VIDEO_UPLOAD',
    NEW.video_id,
    NEW.owner_user_id,
    'Video uploaded: ' || NEW.original_filename,
    jsonb_build_object('filename', NEW.original_filename, 'size_bytes', NEW.file_size_bytes)
);

-- =====================================================
-- VIEWS FOR ANALYTICS
-- =====================================================

-- View: Daily upload statistics
CREATE OR REPLACE VIEW v_daily_uploads AS
SELECT 
    DATE(upload_timestamp) as upload_date,
    COUNT(DISTINCT video_id) as upload_count,
    COUNT(DISTINCT owner_user_id) as unique_uploaders,
    SUM(file_size_bytes) as total_size_bytes,
    AVG(file_size_bytes) as avg_size_bytes
FROM video_metadata
WHERE status != 'deleted'
GROUP BY DATE(upload_timestamp)
ORDER BY upload_date DESC;

-- View: Transcoding status summary
CREATE OR REPLACE VIEW v_transcoding_status AS
SELECT 
    transcoding_status,
    COUNT(DISTINCT video_id) as count,
    AVG(EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - transcoding_timestamp))) as avg_seconds_since_started
FROM video_metadata
WHERE status != 'deleted'
GROUP BY transcoding_status;

-- View: Storage usage by user
CREATE OR REPLACE VIEW v_storage_usage_by_user AS
SELECT 
    owner_user_id,
    COUNT(DISTINCT video_id) as video_count,
    SUM(file_size_bytes) as total_bytes,
    ROUND(SUM(file_size_bytes) / 1024.0 / 1024.0 / 1024.0, 2) as total_gb,
    MAX(upload_timestamp) as latest_upload
FROM video_metadata
WHERE status != 'deleted'
GROUP BY owner_user_id
ORDER BY total_bytes DESC;

-- =====================================================
-- GRANT PERMISSIONS
-- =====================================================

-- Grant select on all tables to app_user (can read)
GRANT SELECT ON video_metadata TO app_user;
GRANT SELECT ON audit_log TO app_user;

-- Grant insert/update on video_metadata to app_user
GRANT INSERT, UPDATE ON video_metadata TO app_user;

-- Grant insert on audit_log to app_user
GRANT INSERT ON audit_log TO app_user;

-- Grant function execution to app_user
GRANT EXECUTE ON FUNCTION log_audit_event TO app_user;
GRANT EXECUTE ON FUNCTION get_user_videos TO app_user;
GRANT EXECUTE ON FUNCTION search_videos TO app_user;
GRANT EXECUTE ON FUNCTION update_transcoding_status TO app_user;
GRANT EXECUTE ON FUNCTION get_video_for_playback TO app_user;
GRANT EXECUTE ON FUNCTION delete_video_metadata TO app_user;

-- Grant select on views to app_user
GRANT SELECT ON v_daily_uploads TO app_user;
GRANT SELECT ON v_transcoding_status TO app_user;
GRANT SELECT ON v_storage_usage_by_user TO app_user;

-- Grant sequence permissions (for SERIAL columns)
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO app_user;

COMMIT;
