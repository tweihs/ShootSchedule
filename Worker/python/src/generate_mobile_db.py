#!/usr/bin/env python3
"""
Simple wrapper script to generate mobile SQLite database from live PostgreSQL.
This script is designed for easy deployment and automation.
"""

import os
import sys
from CreateSqlite import postgres_to_sqlite

def main():
    """Generate mobile SQLite database from live PostgreSQL data."""
    
    print("🚀 ShootSchedule Mobile Database Generator")
    print("=" * 50)
    
    # Determine the correct data directory path
    # When running from python/src, use project root's data directory
    script_dir = os.path.dirname(os.path.abspath(__file__))
    
    # Check if we're in python/src and adjust path accordingly
    if script_dir.endswith('python/src'):
        # Use project root's data directory
        project_root = os.path.abspath(os.path.join(script_dir, '..', '..'))
        data_dir = os.path.join(project_root, 'data')
        output_file = os.path.join(data_dir, 'shoots.sqlite')
    else:
        # Use local data directory (for Docker or other environments)
        data_dir = 'data'
        output_file = 'data/shoots.sqlite'
    
    # Check if custom output path provided
    if len(sys.argv) > 1:
        output_file = sys.argv[1]
    else:
        # Ensure data directory exists
        os.makedirs(data_dir, exist_ok=True)
    
    print(f"📱 Generating mobile database: {output_file}")
    print("🔗 Connecting to live PostgreSQL database...")
    
    try:
        # Generate SQLite from PostgreSQL
        postgres_to_sqlite(output_file)
        
        # Show file size
        file_size = os.path.getsize(output_file)
        size_mb = file_size / (1024 * 1024)
        
        print(f"✅ SUCCESS!")
        print(f"📄 File: {output_file}")
        print(f"💾 Size: {size_mb:.1f} MB ({file_size:,} bytes)")
        
        # Optional: Copy to iOS project if path exists
        ios_path = "../../../iOS/ShootSchedule/shoots.sqlite"
        if os.path.exists(os.path.dirname(os.path.abspath(ios_path))):
            import shutil
            shutil.copy2(output_file, ios_path)
            print(f"📱 Copied to iOS project: {ios_path}")
        
        print("\n🎯 Mobile database ready for deployment!")
        
    except Exception as e:
        print(f"❌ ERROR: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()