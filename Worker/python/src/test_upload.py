#!/usr/bin/env python3
"""
Test script for Firebase Storage upload.
This creates a small test SQLite database and uploads it.

Usage:
    python test_upload.py --credentials path/to/serviceAccountKey.json
"""

import sqlite3
import os
import sys
import argparse
from UploadSqliteToCloud import upload_to_firebase

def create_test_database(filename="test_shoots.sqlite"):
    """Create a small test SQLite database."""
    print(f"📱 Creating test database: {filename}")
    
    # Remove if exists
    if os.path.exists(filename):
        os.remove(filename)
    
    # Create database
    conn = sqlite3.connect(filename)
    cursor = conn.cursor()
    
    # Create shoots table with minimal schema
    cursor.execute('''
    CREATE TABLE shoots (
        "Shoot ID" INTEGER PRIMARY KEY,
        "Shoot Name" TEXT,
        "Start Date" TEXT,
        "Club Name" TEXT,
        "City" TEXT,
        "State" TEXT
    )
    ''')
    
    # Insert some test data
    test_shoots = [
        (1, "Test Championship 2025", "2025-01-15", "Test Gun Club", "Austin", "TX"),
        (2, "Spring Classic", "2025-03-20", "Valley Shooting Range", "Phoenix", "AZ"),
        (3, "Summer Shootout", "2025-06-10", "Mountain View Club", "Denver", "CO"),
    ]
    
    cursor.executemany(
        'INSERT INTO shoots VALUES (?, ?, ?, ?, ?, ?)',
        test_shoots
    )
    
    conn.commit()
    conn.close()
    
    # Get file size
    size = os.path.getsize(filename)
    print(f"✅ Test database created: {size:,} bytes")
    print(f"   Contains {len(test_shoots)} test shoots")
    
    return filename

def main():
    parser = argparse.ArgumentParser(
        description='Test Firebase Storage upload with a small SQLite database'
    )
    parser.add_argument('--credentials', required=True,
                       help='Path to Firebase service account key JSON')
    parser.add_argument('--bucket', 
                       default='shootsdb-11bb7.firebasestorage.app',
                       help='Firebase Storage bucket')
    parser.add_argument('--keep', action='store_true',
                       help='Keep test database after upload')
    
    args = parser.parse_args()
    
    # Check credentials file
    if not os.path.exists(args.credentials):
        print(f"❌ Error: Credentials file not found: {args.credentials}")
        sys.exit(1)
    
    print("=" * 60)
    print("🧪 Firebase Storage Upload Test")
    print("=" * 60)
    
    # Create test database
    test_file = create_test_database()
    
    try:
        # Upload to Firebase
        print("\n🚀 Testing upload to Firebase Storage...")
        print(f"   Bucket: {args.bucket}")
        print(f"   Credentials: {args.credentials}")
        
        url = upload_to_firebase(
            test_file,
            bucket_name=args.bucket,
            credentials_path=args.credentials,
            blob_name="test_shoots.sqlite"
        )
        
        if url:
            print("\n" + "=" * 60)
            print("✅ TEST SUCCESSFUL!")
            print(f"   Test database is available at:")
            print(f"   {url}")
            print("\n📱 You can now test download in the iOS app")
            print("=" * 60)
        else:
            print("\n❌ TEST FAILED")
            sys.exit(1)
            
    finally:
        # Clean up
        if not args.keep and os.path.exists(test_file):
            os.remove(test_file)
            print(f"\n🧹 Cleaned up test file: {test_file}")
        elif args.keep:
            print(f"\n📁 Test file kept: {test_file}")

if __name__ == "__main__":
    main()