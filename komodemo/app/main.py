"""
Video Processing Platform - Cloud Run Application
Handles video uploads, metadata storage, and transcoding triggers
"""

import os
import json
import logging
import uuid
from datetime import datetime
from functools import wraps
from typing import Tuple, Dict, Any

import flask
from flask import Flask, request, jsonify
from werkzeug.utils import secure_filename
import psycopg2
from psycopg2 import pool
from psycopg2.extras import RealDictCursor
from google.cloud import storage
from google.cloud import pubsub_v1
from google.auth import default

# Configure logging
logging.basicConfig(level=os.getenv('LOG_LEVEL', 'INFO'))
logger = logging.getLogger(__name__)

# Flask app initialization
app = Flask(__name__)

# Configuration
BUCKET_NAME = os.getenv('BUCKET_NAME', 'play-video-upload-01')
DATABASE_URL = os.getenv('DATABASE_URL', '')
CLOUD_SQL_INSTANCE = os.getenv('CLOUD_SQL_INSTANCE', '')
DB_USER = os.getenv('DB_USER', 'app_user')
DB_PASSWORD = os.getenv('DB_PASSWORD', '')
DB_NAME = os.getenv('DB_NAME', 'video_metadata')
ALLOWED_EXTENSIONS = {'mp4', 'avi', 'mov', 'mkv', 'flv', 'wmv'}
MAX_FILE_SIZE = 5 * 1024 * 1024 * 1024  # 5GB

# Initialize GCP clients
storage_client = storage.Client()
publisher_client = pubsub_v1.PublisherClient()

# Database connection pool
db_pool = None


def init_db_pool():
    """Initialize database connection pool"""
    global db_pool
    try:
        db_pool = psycopg2.pool.SimpleConnectionPool(
            1, 20,
            host=f"/cloudsql/{CLOUD_SQL_INSTANCE}",
            user=DB_USER,
            password=DB_PASSWORD,
            database=DB_NAME,
            sslmode='require'
        )
        logger.info("Database connection pool initialized successfully")
    except Exception as e:
        logger.error(f"Failed to initialize database pool: {str(e)}")
        raise


def get_db_connection():
    """Get connection from pool"""
    if db_pool is None:
        init_db_pool()
    return db_pool.getconn()


def return_db_connection(conn):
    """Return connection to pool"""
    if db_pool:
        db_pool.putconn(conn)


def require_auth(f):
    """Decorator to check Authorization header"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        auth_header = request.headers.get('Authorization')
        if not auth_header:
            return jsonify({'error': 'Missing Authorization header'}), 401
        return f(*args, **kwargs)
    return decorated_function


def insert_video_metadata(video_id: str, filename: str, gcs_path: str, 
                         user_id: str, file_size: int, owner_id: str) -> bool:
    """Insert video metadata into Cloud SQL"""
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        sql = """
            INSERT INTO video_metadata (
                video_id, original_filename, gcs_original_path,
                file_size_bytes, owner_user_id, status, upload_timestamp
            ) VALUES (%s, %s, %s, %s, %s, %s, CURRENT_TIMESTAMP)
        """
        
        cursor.execute(sql, (video_id, filename, gcs_path, file_size, owner_id, 'uploaded'))
        conn.commit()
        logger.info(f"Metadata inserted for video: {video_id}")
        return True
        
    except Exception as e:
        logger.error(f"Error inserting metadata: {str(e)}")
        if conn:
            conn.rollback()
        return False
    finally:
        if cursor:
            cursor.close()
        if conn:
            return_db_connection(conn)


def publish_transcoding_event(video_id: str, gcs_path: str, owner_id: str):
    """Publish event to trigger transcoding"""
    try:
        topic_path = publisher_client.topic_path(
            os.getenv('GCP_PROJECT_ID'),
            'video-processing-topic'
        )
        
        message_json = json.dumps({
            'video_id': video_id,
            'gcs_path': gcs_path,
            'owner_id': owner_id,
            'timestamp': datetime.utcnow().isoformat()
        })
        message_bytes = message_json.encode('utf-8')
        
        publish_future = publisher_client.publish(topic_path, message_bytes)
        message_id = publish_future.result()
        logger.info(f"Transcoding event published: {message_id}")
        return True
    except Exception as e:
        logger.error(f"Error publishing transcoding event: {str(e)}")
        return False


@app.route('/health', methods=['GET'])
def health_check() -> Tuple[Dict[str, Any], int]:
    """Health check endpoint for Cloud Run"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT 1")
        cursor.close()
        return_db_connection(conn)
        return {'status': 'healthy', 'timestamp': datetime.utcnow().isoformat()}, 200
    except Exception as e:
        logger.error(f"Health check failed: {str(e)}")
        return {'status': 'unhealthy', 'error': str(e)}, 503


@app.route('/upload', methods=['POST'])
@require_auth
def upload_video() -> Tuple[Dict[str, Any], int]:
    """Handle video upload"""
    try:
        # Validate request
        if 'file' not in request.files:
            return {'error': 'No file provided'}, 400
        
        file = request.files['file']
        if file.filename == '':
            return {'error': 'Empty filename'}, 400
        
        filename = secure_filename(file.filename)
        ext = filename.rsplit('.', 1)[1].lower() if '.' in filename else ''
        
        if ext not in ALLOWED_EXTENSIONS:
            return {'error': f'File type .{ext} not allowed'}, 400
        
        # Get user info from request
        user_id = request.form.get('user_id', 'anonymous')
        visibility = request.form.get('visibility', 'private')
        allow_download = request.form.get('allow_download', 'false').lower() == 'true'
        
        # Generate unique video ID
        video_id = str(uuid.uuid4())
        
        # Upload to GCS
        bucket = storage_client.bucket(BUCKET_NAME)
        gcs_path = f"uploads/{user_id}/{video_id}/{filename}"
        blob = bucket.blob(gcs_path)
        
        file.seek(0, 2)  # Seek to end
        file_size = file.tell()
        file.seek(0)  # Reset to beginning
        
        if file_size > MAX_FILE_SIZE:
            return {'error': f'File size exceeds {MAX_FILE_SIZE / (1024**3):.1f}GB limit'}, 413
        
        # Upload with metadata
        blob.upload_from_string(
            file.read(),
            content_type=file.content_type,
            metadata={
                'original_filename': filename,
                'upload_time': datetime.utcnow().isoformat(),
                'uploader_id': user_id
            }
        )
        logger.info(f"Video uploaded to GCS: {gcs_path}")
        
        # Insert metadata into Cloud SQL
        if not insert_video_metadata(video_id, filename, gcs_path, user_id, file_size, user_id):
            return {'error': 'Failed to store metadata'}, 500
        
        # Update video metadata with visibility and download settings
        update_metadata(video_id, visibility=visibility, download_allowed=allow_download)
        
        # Publish transcoding event
        publish_transcoding_event(video_id, gcs_path, user_id)
        
        return {
            'success': True,
            'video_id': video_id,
            'gcs_path': gcs_path,
            'message': 'Video uploaded successfully. Processing started.'
        }, 202
        
    except Exception as e:
        logger.error(f"Upload error: {str(e)}")
        return {'error': str(e)}, 500


@app.route('/metadata/<video_id>', methods=['GET'])
@require_auth
def get_video_metadata(video_id: str) -> Tuple[Dict[str, Any], int]:
    """Retrieve video metadata"""
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        sql = "SELECT * FROM video_metadata WHERE video_id = %s"
        cursor.execute(sql, (video_id,))
        result = cursor.fetchone()
        cursor.close()
        
        if not result:
            return {'error': 'Video not found'}, 404
        
        return dict(result), 200
        
    except Exception as e:
        logger.error(f"Error retrieving metadata: {str(e)}")
        return {'error': str(e)}, 500
    finally:
        if conn:
            return_db_connection(conn)


@app.route('/metadata/<video_id>', methods=['PUT'])
@require_auth
def update_video_metadata(video_id: str) -> Tuple[Dict[str, Any], int]:
    """Update video metadata"""
    try:
        data = request.get_json() or {}
        return update_metadata(video_id, **data), 200
    except Exception as e:
        logger.error(f"Error updating metadata: {str(e)}")
        return {'error': str(e)}, 500


def update_metadata(video_id: str, **kwargs) -> Dict[str, Any]:
    """Update video metadata in database"""
    conn = None
    try:
        allowed_fields = {
            'visibility': 'visibility',
            'download_allowed': 'download_allowed',
            'status': 'status',
            'transcoding_status': 'transcoding_status'
        }
        
        updates = []
        values = []
        
        for key, db_col in allowed_fields.items():
            if key in kwargs:
                updates.append(f"{db_col} = %s")
                values.append(kwargs[key])
        
        if not updates:
            return {'error': 'No valid fields to update'}
        
        values.append(video_id)
        conn = get_db_connection()
        cursor = conn.cursor()
        
        sql = f"UPDATE video_metadata SET {', '.join(updates)}, updated_at = CURRENT_TIMESTAMP WHERE video_id = %s"
        cursor.execute(sql, values)
        conn.commit()
        
        logger.info(f"Metadata updated for video: {video_id}")
        return {'success': True, 'video_id': video_id}
        
    except Exception as e:
        logger.error(f"Error updating metadata: {str(e)}")
        if conn:
            conn.rollback()
        return {'error': str(e)}
    finally:
        if cursor:
            cursor.close()
        if conn:
            return_db_connection(conn)


@app.route('/videos/<owner_id>', methods=['GET'])
@require_auth
def list_user_videos(owner_id: str) -> Tuple[Dict[str, Any], int]:
    """List videos for a user"""
    conn = None
    try:
        visibility = request.args.get('visibility', 'public')
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        sql = """
            SELECT video_id, original_filename, upload_timestamp, status,
                   transcoding_status, visibility, file_size_bytes
            FROM video_metadata
            WHERE owner_user_id = %s AND visibility = %s
            ORDER BY upload_timestamp DESC
            LIMIT 100
        """
        
        cursor.execute(sql, (owner_id, visibility))
        videos = [dict(row) for row in cursor.fetchall()]
        cursor.close()
        
        return {'videos': videos, 'count': len(videos)}, 200
        
    except Exception as e:
        logger.error(f"Error listing videos: {str(e)}")
        return {'error': str(e)}, 500
    finally:
        if conn:
            return_db_connection(conn)


@app.route('/search', methods=['GET'])
@require_auth
def search_videos() -> Tuple[Dict[str, Any], int]:
    """Search videos by metadata"""
    conn = None
    try:
        query = request.args.get('q', '').strip()
        owner_id = request.args.get('owner_id', '')
        status = request.args.get('status', '')
        
        if not query and not owner_id:
            return {'error': 'Provide search query or owner_id'}, 400
        
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        where_clauses = ["visibility = 'public'"]
        params = []
        
        if query:
            where_clauses.append("original_filename ILIKE %s")
            params.append(f"%{query}%")
        
        if owner_id:
            where_clauses.append("owner_user_id = %s")
            params.append(owner_id)
        
        if status:
            where_clauses.append("status = %s")
            params.append(status)
        
        sql = f"""
            SELECT video_id, original_filename, upload_timestamp,
                   status, transcoding_status, owner_user_id
            FROM video_metadata
            WHERE {' AND '.join(where_clauses)}
            ORDER BY upload_timestamp DESC
            LIMIT 50
        """
        
        cursor.execute(sql, params)
        videos = [dict(row) for row in cursor.fetchall()]
        cursor.close()
        
        return {'videos': videos, 'count': len(videos)}, 200
        
    except Exception as e:
        logger.error(f"Search error: {str(e)}")
        return {'error': str(e)}, 500
    finally:
        if conn:
            return_db_connection(conn)


@app.route('/audit-log', methods=['GET'])
@require_auth
def get_audit_log() -> Tuple[Dict[str, Any], int]:
    """Retrieve audit logs"""
    conn = None
    try:
        video_id = request.args.get('video_id')
        user_id = request.args.get('user_id')
        limit = int(request.args.get('limit', '50'))
        
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        where_clauses = []
        params = []
        
        if video_id:
            where_clauses.append("video_id = %s")
            params.append(video_id)
        
        if user_id:
            where_clauses.append("user_id = %s")
            params.append(user_id)
        
        where = f"WHERE {' AND '.join(where_clauses)}" if where_clauses else ""
        
        sql = f"""
            SELECT * FROM audit_log
            {where}
            ORDER BY timestamp DESC
            LIMIT %s
        """
        params.append(limit)
        
        cursor.execute(sql, params)
        logs = [dict(row) for row in cursor.fetchall()]
        cursor.close()
        
        return {'audit_logs': logs, 'count': len(logs)}, 200
        
    except Exception as e:
        logger.error(f"Error retrieving audit logs: {str(e)}")
        return {'error': str(e)}, 500
    finally:
        if conn:
            return_db_connection(conn)


@app.errorhandler(404)
def not_found(error):
    """404 handler"""
    return {'error': 'Endpoint not found'}, 404


@app.errorhandler(500)
def server_error(error):
    """500 handler"""
    logger.error(f"Internal server error: {str(error)}")
    return {'error': 'Internal server error'}, 500


if __name__ == '__main__':
    # Initialize database pool on startup
    init_db_pool()
    
    # Run Flask app
    port = int(os.getenv('PORT', 8080))
    app.run(host='0.0.0.0', port=port, debug=False)
