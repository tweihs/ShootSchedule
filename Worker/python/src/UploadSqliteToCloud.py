#!/usr/bin/env python3
"""
Upload SQLite database to Firebase Cloud Storage.
This is a standalone script that can be run independently or imported.

Usage:
    python UploadSqliteToCloud.py shoots.sqlite
    
    # With custom bucket
    python UploadSqliteToCloud.py shoots.sqlite --bucket custom-bucket.appspot.com
    
    # With custom credentials
    python UploadSqliteToCloud.py shoots.sqlite --credentials path/to/key.json
    
Environment Variables:
    GOOGLE_APPLICATION_CREDENTIALS: Path to service account key file
    FIREBASE_STORAGE_BUCKET: Storage bucket name (optional)
"""

import os
import sys
import json
import hashlib
import argparse
from datetime import datetime, timezone
import firebase_admin
from firebase_admin import credentials
from pathlib import Path

def calculate_file_hash(file_path):
    """Calculate SHA-256 hash of a file."""
    sha256_hash = hashlib.sha256()
    with open(file_path, "rb") as f:
        for byte_block in iter(lambda: f.read(4096), b""):
            sha256_hash.update(byte_block)
    return sha256_hash.hexdigest()

def get_file_metadata(file_path):
    """Get metadata about the file."""
    file_stats = os.stat(file_path)
    file_size = file_stats.st_size
    file_hash = calculate_file_hash(file_path)
    
    metadata = {
        'file_hash': file_hash,
        'file_size': file_size,
        'file_size_mb': round(file_size / (1024 * 1024), 2),
        'uploaded_at': datetime.now(timezone.utc).isoformat(),
        'original_name': os.path.basename(file_path)
    }
    
    # Try to get shoot count if it's a valid SQLite database
    try:
        import sqlite3
        conn = sqlite3.connect(file_path)
        cursor = conn.cursor()
        cursor.execute("SELECT COUNT(*) FROM shoots")
        shoot_count = cursor.fetchone()[0]
        metadata['shoot_count'] = shoot_count
        conn.close()
    except Exception as e:
        print(f"⚠️ Could not read shoot count: {e}")
        metadata['shoot_count'] = 0
    
    return metadata

def upload_to_firebase(file_path, bucket_name=None, credentials_path=None, blob_name="shoots.sqlite"):
    """
    Upload file to Firebase Storage.
    
    Args:
        file_path: Path to the SQLite file to upload
        bucket_name: Firebase Storage bucket (e.g., 'shootsdb-11bb7.firebasestorage.app')
        credentials_path: Path to service account key JSON file
        blob_name: Name for the file in storage (default: 'shoots.sqlite')
    
    Returns:
        Public URL of the uploaded file, or None if failed
    """
    try:
        import firebase_admin
        from firebase_admin import credentials, storage
    except ImportError:
        print("❌ Error: firebase-admin not installed")
        print("   Run: pip install firebase-admin")
        return None
    
    # Determine bucket name
    if not bucket_name:
        bucket_name = os.getenv('FIREBASE_STORAGE_BUCKET', 'shootsdb-11bb7.firebasestorage.app')
    
    print(f"🪣 Using Firebase Storage bucket: {bucket_name}")
    
    # Initialize Firebase Admin SDK if not already initialized
    if not firebase_admin._apps:
        try:
            # Use provided credentials path, check common locations, or use environment variable
            if not credentials_path:
                # Check for serviceAccountKey.json in common locations
                possible_paths = [
                    "serviceAccountKey.json",  # Current directory
                    "../serviceAccountKey.json",  # Parent directory
                    "../../serviceAccountKey.json",  # Two directories up (project root from python/src)
                    os.path.expanduser("~/serviceAccountKey.json"),  # Home directory
                ]
                
                for path in possible_paths:
                    if os.path.exists(path):
                        credentials_path = path
                        print(f"🔍 Found credentials at: {path}")
                        break
                
                # Fall back to environment variable
                if not credentials_path:
                    credentials_path = os.getenv('GOOGLE_APPLICATION_CREDENTIALS')
            
            if not credentials_path:
                print("❌ Error: No credentials found")
                print("   Checked: serviceAccountKey.json in current, parent, and project root")
                print("   Set GOOGLE_APPLICATION_CREDENTIALS environment variable")
                print("   Or use --credentials flag")
                return None
            
            if not os.path.exists(credentials_path):
                print(f"❌ Error: Credentials file not found: {credentials_path}")
                return None
            
            # Firebase recommended initialization
            print(f"🔑 Loading credentials from: {credentials_path}")
            cred = credentials.Certificate(credentials_path)
            firebase_admin.initialize_app(cred, {
                'storageBucket': bucket_name
            })
            print("✅ Firebase Admin SDK initialized")
            
        except Exception as e:
            print(f"❌ Failed to initialize Firebase: {e}")
            return None
    
    try:
        # Get bucket and create blob
        bucket = storage.bucket()
        blob = bucket.blob(blob_name)
        
        # Get file metadata
        print(f"📊 Analyzing file: {file_path}")
        metadata = get_file_metadata(file_path)
        
        print(f"   Size: {metadata['file_size_mb']} MB")
        print(f"   Hash: {metadata['file_hash'][:16]}...")
        print(f"   Shoots: {metadata.get('shoot_count', 'unknown')}")
        
        # Set blob metadata
        blob.metadata = {
            'fileHash': metadata['file_hash'],
            'fileSize': str(metadata['file_size']),
            'shootCount': str(metadata.get('shoot_count', 0)),
            'uploadedAt': metadata['uploaded_at'],
            'originalName': metadata['original_name']
        }
        
        # Set cache control for CDN optimization
        blob.cache_control = 'public, max-age=3600'  # Cache for 1 hour
        blob.content_type = 'application/x-sqlite3'
        
        # Upload the file
        print(f"📤 Uploading to Firebase Storage...")
        blob.upload_from_filename(file_path)
        
        # Make it publicly accessible
        blob.make_public()
        
        # Get the public URL
        public_url = f"https://firebasestorage.googleapis.com/v0/b/{bucket_name}/o/{blob_name}?alt=media"
        
        print(f"✅ Upload successful!")
        print(f"🌐 Public URL: {public_url}")
        print(f"📱 Direct download: https://storage.googleapis.com/{bucket_name}/{blob_name}")
        
        # Save upload info to local file for reference
        upload_info = {
            'file': file_path,
            'bucket': bucket_name,
            'blob': blob_name,
            'public_url': public_url,
            'metadata': metadata,
            'uploaded_at': datetime.now(timezone.utc).isoformat()
        }
        
        info_file = f"{file_path}.upload_info.json"
        with open(info_file, 'w') as f:
            json.dump(upload_info, f, indent=2)
        print(f"📝 Upload info saved to: {info_file}")
        
        return public_url
        
    except Exception as e:
        print(f"❌ Upload failed: {e}")
        import traceback
        traceback.print_exc()
        return None

def main():
    """Main function for command-line usage."""
    parser = argparse.ArgumentParser(
        description='Upload SQLite database to Firebase Cloud Storage',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Upload with default settings
  python UploadSqliteToCloud.py shoots.sqlite
  
  # Upload with custom bucket
  python UploadSqliteToCloud.py shoots.sqlite --bucket my-app.appspot.com
  
  # Upload with specific credentials
  python UploadSqliteToCloud.py shoots.sqlite --credentials ~/keys/firebase-key.json
  
  # Upload with custom name in storage
  python UploadSqliteToCloud.py local.db --blob-name production.sqlite
  
Environment Variables:
  GOOGLE_APPLICATION_CREDENTIALS: Default path to service account key
  FIREBASE_STORAGE_BUCKET: Default storage bucket name
        """
    )
    
    parser.add_argument('file', nargs='?', default='data/shoots.sqlite',
                       help='Path to SQLite file to upload (default: data/shoots.sqlite)')
    parser.add_argument('--bucket', help='Firebase Storage bucket name')
    parser.add_argument('--credentials', help='Path to service account key JSON')
    parser.add_argument('--blob-name', default='shoots.sqlite', 
                       help='Name for file in storage (default: shoots.sqlite)')
    parser.add_argument('--verify', action='store_true',
                       help='Verify the file is a valid SQLite database before upload')
    
    args = parser.parse_args()
    
    # If using default path, check multiple locations for the data directory
    if args.file == 'data/shoots.sqlite' and not os.path.exists(args.file):
        possible_paths = [
            'data/shoots.sqlite',  # Current directory
            '../data/shoots.sqlite',  # Parent directory
            '../../data/shoots.sqlite',  # Project root from python/src
            'shoots.sqlite',  # Current directory without data/
            '../shoots.sqlite',  # Parent directory
        ]
        
        for path in possible_paths:
            if os.path.exists(path):
                args.file = path
                print(f"🔍 Found database at: {path}")
                break
    
    # Check if file exists
    if not os.path.exists(args.file):
        print(f"❌ Error: File not found: {args.file}")
        if args.file == 'data/shoots.sqlite':
            print("   Checked: data/shoots.sqlite in current, parent, and project directories")
            print("   Please specify the path to your SQLite file")
        sys.exit(1)
    
    # Verify SQLite if requested
    if args.verify:
        try:
            import sqlite3
            conn = sqlite3.connect(args.file)
            cursor = conn.cursor()
            cursor.execute("SELECT name FROM sqlite_master WHERE type='table' LIMIT 1")
            tables = cursor.fetchone()
            conn.close()
            if not tables:
                print("❌ Error: File is not a valid SQLite database or has no tables")
                sys.exit(1)
            print("✅ File is a valid SQLite database")
        except Exception as e:
            print(f"❌ Error: File verification failed: {e}")
            sys.exit(1)
    
    # Upload the file
    print("=" * 60)
    print("🚀 Firebase Storage Upload Tool")
    print("=" * 60)
    
    url = upload_to_firebase(
        args.file,
        bucket_name=args.bucket,
        credentials_path=args.credentials,
        blob_name=args.blob_name
    )
    
    if url:
        print("\n" + "=" * 60)
        print("🎉 SUCCESS! Database is now available at:")
        print(f"   {url}")
        print("=" * 60)
        sys.exit(0)
    else:
        print("\n❌ Upload failed. Check the error messages above.")
        sys.exit(1)

if __name__ == "__main__":
    main()