#!/usr/bin/env python3
"""
Deploy mobile SQLite database to cloud storage.
This script generates the SQLite database from PostgreSQL and uploads it to 
cloud storage (S3, Google Cloud Storage, or Firebase Storage) with proper 
metadata for last-modified checks.
"""

import os
import sys
import hashlib
import json
from datetime import datetime, timezone
import boto3
from botocore.exceptions import NoCredentialsError
import requests
from pathlib import Path

# Import the existing database generation functions
from CreateSqlite import postgres_to_sqlite
from CreateSqliteWithWeather import postgres_to_sqlite_with_weather

# Configuration from environment variables
STORAGE_TYPE = os.getenv('STORAGE_TYPE', 'S3')  # S3, GCS, or FIREBASE
S3_BUCKET = os.getenv('S3_BUCKET', 'shootschedule-mobile')
S3_REGION = os.getenv('S3_REGION', 'us-east-1')
S3_KEY = os.getenv('S3_KEY', 'databases/shoots.sqlite')
FIREBASE_STORAGE_BUCKET = os.getenv('FIREBASE_STORAGE_BUCKET')
GCS_BUCKET = os.getenv('GCS_BUCKET')
CDN_URL = os.getenv('CDN_URL', 'https://shootschedule-mobile.s3.amazonaws.com')

def calculate_file_hash(file_path):
    """Calculate SHA-256 hash of a file."""
    sha256_hash = hashlib.sha256()
    with open(file_path, "rb") as f:
        for byte_block in iter(lambda: f.read(4096), b""):
            sha256_hash.update(byte_block)
    return sha256_hash.hexdigest()

def upload_to_s3(file_path, metadata):
    """Upload SQLite file to Amazon S3 with metadata."""
    try:
        s3_client = boto3.client('s3', region_name=S3_REGION)
        
        # Prepare metadata for S3
        s3_metadata = {
            'last-modified': metadata['last_modified'],
            'file-hash': metadata['file_hash'],
            'file-size': str(metadata['file_size']),
            'database-version': metadata.get('database_version', '1.0'),
            'shoot-count': str(metadata.get('shoot_count', 0))
        }
        
        # Upload file with metadata
        with open(file_path, 'rb') as f:
            s3_client.put_object(
                Bucket=S3_BUCKET,
                Key=S3_KEY,
                Body=f,
                ContentType='application/x-sqlite3',
                CacheControl='public, max-age=3600',  # Cache for 1 hour
                Metadata=s3_metadata
            )
        
        # Also upload a manifest file with detailed metadata
        manifest_key = S3_KEY.replace('.sqlite', '_manifest.json')
        manifest_data = {
            **metadata,
            'download_url': f"{CDN_URL}/{S3_KEY}",
            'manifest_url': f"{CDN_URL}/{manifest_key}"
        }
        
        s3_client.put_object(
            Bucket=S3_BUCKET,
            Key=manifest_key,
            Body=json.dumps(manifest_data, indent=2),
            ContentType='application/json',
            CacheControl='public, max-age=300'  # Cache manifest for 5 minutes
        )
        
        print(f"✅ Uploaded to S3: s3://{S3_BUCKET}/{S3_KEY}")
        print(f"📄 Manifest: s3://{S3_BUCKET}/{manifest_key}")
        print(f"🌐 Public URL: {CDN_URL}/{S3_KEY}")
        return f"{CDN_URL}/{S3_KEY}"
        
    except NoCredentialsError:
        print("❌ AWS credentials not found")
        return None
    except Exception as e:
        print(f"❌ S3 upload failed: {e}")
        return None

def upload_to_firebase_storage(file_path, metadata):
    """Upload SQLite file to Firebase Storage with metadata."""
    try:
        import firebase_admin
        from firebase_admin import credentials, storage
        
        # Get the storage bucket from environment or use default
        storage_bucket = os.getenv('FIREBASE_STORAGE_BUCKET', 'shootsdb-11bb7.firebasestorage.app')
        
        # Initialize Firebase Admin SDK if not already initialized
        if not firebase_admin._apps:
            # Try multiple credential sources
            cred = None
            
            # 1. Check for credentials JSON in environment variable (Heroku style)
            cred_json = os.getenv('GOOGLE_CREDENTIALS')
            if cred_json:
                try:
                    import json as json_lib
                    cred_dict = json_lib.loads(cred_json)
                    cred = credentials.Certificate(cred_dict)
                    print("📋 Using credentials from GOOGLE_CREDENTIALS env var")
                except Exception as e:
                    print(f"⚠️ Failed to parse GOOGLE_CREDENTIALS: {e}")
            
            # 2. Check for service account file path
            if not cred:
                cred_path = os.getenv('GOOGLE_APPLICATION_CREDENTIALS')
                if cred_path and os.path.exists(cred_path):
                    cred = credentials.Certificate(cred_path)
                    print("📋 Using credentials from file: {cred_path}")
            
            # 3. Try application default credentials
            if not cred:
                try:
                    cred = credentials.ApplicationDefault()
                    print("📋 Using Application Default Credentials")
                except Exception:
                    raise Exception("No Firebase credentials found. Set GOOGLE_CREDENTIALS or GOOGLE_APPLICATION_CREDENTIALS")
            
            firebase_admin.initialize_app(cred, {
                'storageBucket': storage_bucket
            })
        
        bucket = storage.bucket()
        
        # Upload to root directory as shoots.sqlite
        blob = bucket.blob('shoots.sqlite')
        
        # Set metadata including cache control and content type
        blob.metadata = {
            'lastModified': metadata['last_modified'],
            'fileHash': metadata['file_hash'],
            'fileSize': str(metadata['file_size']),
            'databaseVersion': metadata.get('database_version', '1.0'),
            'shootCount': str(metadata.get('shoot_count', 0)),
            'includesWeather': str(metadata.get('includes_weather', False))
        }
        blob.cache_control = 'public, max-age=3600'  # Cache for 1 hour
        blob.content_type = 'application/x-sqlite3'
        
        # Upload file
        print(f"📤 Uploading to Firebase Storage bucket: {storage_bucket}")
        blob.upload_from_filename(file_path)
        
        # Make the file publicly readable
        blob.make_public()
        
        # Get the public URL
        public_url = f"https://firebasestorage.googleapis.com/v0/b/{storage_bucket}/o/shoots.sqlite?alt=media"
        
        print(f"✅ Uploaded to Firebase Storage")
        print(f"🌐 Public URL: {public_url}")
        print(f"📊 Metadata set: Last-Modified={metadata['last_modified']}")
        print(f"🏷️ ETag will be automatically generated by Firebase")
        
        return public_url
        
    except Exception as e:
        print(f"❌ Firebase Storage upload failed: {e}")
        print(f"   Make sure GOOGLE_APPLICATION_CREDENTIALS is set to your service account key file")
        print(f"   Or that Application Default Credentials are configured")
        return None

def upload_to_gcs(file_path, metadata):
    """Upload SQLite file to Google Cloud Storage with metadata."""
    try:
        from google.cloud import storage
        
        client = storage.Client()
        bucket = client.bucket(GCS_BUCKET)
        blob = bucket.blob('databases/shoots.sqlite')
        
        # Set metadata
        blob.metadata = {
            'last-modified': metadata['last_modified'],
            'file-hash': metadata['file_hash'],
            'file-size': str(metadata['file_size']),
            'database-version': metadata.get('database_version', '1.0'),
            'shoot-count': str(metadata.get('shoot_count', 0))
        }
        
        # Upload file
        blob.upload_from_filename(file_path)
        
        # Make the file publicly readable
        blob.make_public()
        
        # Upload manifest
        manifest_blob = bucket.blob('databases/shoots_manifest.json')
        manifest_data = {
            **metadata,
            'download_url': blob.public_url,
            'manifest_url': f"https://storage.googleapis.com/{GCS_BUCKET}/databases/shoots_manifest.json"
        }
        manifest_blob.upload_from_string(
            json.dumps(manifest_data, indent=2),
            content_type='application/json'
        )
        manifest_blob.make_public()
        
        print(f"✅ Uploaded to GCS: {blob.public_url}")
        print(f"📄 Manifest: {manifest_blob.public_url}")
        return blob.public_url
        
    except Exception as e:
        print(f"❌ GCS upload failed: {e}")
        return None

def get_shoot_count(sqlite_file):
    """Get the count of shoots in the database."""
    import sqlite3
    try:
        conn = sqlite3.connect(sqlite_file)
        cursor = conn.cursor()
        cursor.execute("SELECT COUNT(*) FROM shoots")
        count = cursor.fetchone()[0]
        conn.close()
        return count
    except Exception as e:
        print(f"⚠️ Could not get shoot count: {e}")
        return 0

def main():
    """Main function to generate and deploy the mobile database."""
    
    print("🚀 ShootSchedule Mobile Database Deployment")
    print("=" * 50)
    
    # Generate the SQLite database
    output_file = "shoots_mobile.sqlite"
    
    # Check if we should include weather data
    include_weather = os.getenv('INCLUDE_WEATHER', 'true').lower() == 'true'
    
    print(f"📱 Generating mobile database: {output_file}")
    print(f"🌡️ Including weather data: {include_weather}")
    print("🔗 Connecting to PostgreSQL database...")
    
    try:
        if include_weather:
            postgres_to_sqlite_with_weather(output_file)
        else:
            postgres_to_sqlite(output_file)
        
        # Get file statistics
        file_stats = os.stat(output_file)
        file_size = file_stats.st_size
        file_hash = calculate_file_hash(output_file)
        shoot_count = get_shoot_count(output_file)
        
        # Prepare metadata
        metadata = {
            'last_modified': datetime.now(timezone.utc).isoformat(),
            'file_hash': file_hash,
            'file_size': file_size,
            'file_size_mb': round(file_size / (1024 * 1024), 2),
            'database_version': os.getenv('DATABASE_VERSION', '1.0'),
            'shoot_count': shoot_count,
            'generated_at': datetime.now(timezone.utc).isoformat(),
            'includes_weather': include_weather
        }
        
        print(f"✅ Database generated successfully!")
        print(f"📄 File: {output_file}")
        print(f"💾 Size: {metadata['file_size_mb']} MB ({file_size:,} bytes)")
        print(f"🎯 Shoots: {shoot_count:,}")
        print(f"🔐 Hash: {file_hash[:16]}...")
        
        # Upload to cloud storage
        print(f"\n☁️ Uploading to {STORAGE_TYPE}...")
        
        if STORAGE_TYPE == 'S3':
            url = upload_to_s3(output_file, metadata)
        elif STORAGE_TYPE == 'FIREBASE':
            url = upload_to_firebase_storage(output_file, metadata)
        elif STORAGE_TYPE == 'GCS':
            url = upload_to_gcs(output_file, metadata)
        else:
            print(f"❌ Unknown storage type: {STORAGE_TYPE}")
            sys.exit(1)
        
        if url:
            print(f"\n🎉 Deployment complete!")
            print(f"📱 iOS app can download from: {url}")
            
            # Save deployment info locally
            deployment_info = {
                'url': url,
                'metadata': metadata,
                'storage_type': STORAGE_TYPE
            }
            with open('deployment_info.json', 'w') as f:
                json.dump(deployment_info, f, indent=2)
            print(f"💾 Deployment info saved to deployment_info.json")
            
            # Notify any webhooks if configured
            webhook_url = os.getenv('DEPLOYMENT_WEBHOOK_URL')
            if webhook_url:
                try:
                    response = requests.post(webhook_url, json=deployment_info)
                    if response.status_code == 200:
                        print(f"🔔 Webhook notified: {webhook_url}")
                except:
                    pass
        else:
            print("❌ Deployment failed")
            sys.exit(1)
            
    except Exception as e:
        print(f"❌ ERROR: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()