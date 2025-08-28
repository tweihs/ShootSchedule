#!/usr/bin/env python3
"""
Complete workflow for processing shoot schedules and deploying mobile database.
This script orchestrates the entire process from downloading Excel files to 
deploying the SQLite database to cloud storage.

Usage:
    python process_and_deploy.py [--force]
    
Options:
    --force  Force re-download and processing of all files, ignoring cache
"""

import os
import sys
import time
import json
import argparse
from datetime import datetime
from pathlib import Path

# Import existing modules
from DownloadShootFilesWithLastModified import download_files
from MergeShootData import merge
from GeocodeEventData import main as geocode_data
from CreatePostgresLoadScript import load_and_insert_data
from generate_mobile_db import main as generate_database
from UploadSqliteToCloud import upload_to_firebase

def run_workflow(force=False):
    """Run the complete workflow for processing and deploying shoot data.
    
    Args:
        force: If True, force re-download and processing, ignoring cache
    """
    
    print("=" * 60)
    print("🎯 ShootSchedule Complete Processing Workflow")
    if force:
        print("🔄 FORCE MODE: Re-downloading all files")
    print("=" * 60)
    print(f"⏰ Started at: {datetime.now().isoformat()}")
    print()
    
    # Determine output directory - always use project root's data directory
    if os.path.exists('/.dockerenv') or os.getenv('IN_DOCKER'):
        output_dir = "/app/data"
    else:
        # Get the script's directory and find project root
        script_dir = os.path.dirname(os.path.abspath(__file__))
        if script_dir.endswith('python/src'):
            # Running from python/src, use project root's data directory
            project_root = os.path.abspath(os.path.join(script_dir, '..', '..'))
            output_dir = os.path.join(project_root, 'data')
        else:
            # Running from somewhere else, use relative path
            output_dir = "../data"
    
    # Ensure output directory exists
    Path(output_dir).mkdir(parents=True, exist_ok=True)
    print(f"📁 Using data directory: {os.path.abspath(output_dir)}")
    
    workflow_steps = []
    start_time = time.time()
    
    try:
        # Step 1: Download latest Excel files
        print("📥 Step 1: Downloading latest shoot schedule files...")
        print("-" * 40)
        
        current_year = datetime.now().year
        next_year = current_year + 1
        
        # URLs for NSSA and NSCA Excel files
        urls = [
            f"https://www.nssa-nsca.org/Schedules/NSSA_{current_year}_Shoot_Schedule_For_Web.xls",
            f"https://www.nssa-nsca.org/Schedules/NSSA_{next_year}_Shoot_Schedule_For_Web.xls",
            f"https://www.nssa-nsca.org/Schedules/NSCA_{current_year}_Shoot_Schedule_For_Web.xls",
            f"https://www.nssa-nsca.org/Schedules/NSCA_{next_year}_Shoot_Schedule_For_Web.xls"
        ]
        
        # Filter URLs to only current year NSSA and NSCA
        urls = [urls[0], urls[2]]  # Current year NSSA and NSCA
        
        # If force mode, delete the last_modified.json cache file
        if force:
            cache_file = os.path.join(output_dir, 'last_modified.json')
            if os.path.exists(cache_file):
                os.remove(cache_file)
                print(f"🗑️ Removed cache file: {cache_file}")
        
        downloaded = download_files(urls, output_dir)
        
        if any(downloaded) or force:
            if any(downloaded):
                print("✅ New files downloaded")
            elif force:
                print("🔄 Force mode - processing existing files")
            workflow_steps.append({
                'step': 'download',
                'status': 'success',
                'files_updated': sum(downloaded)
            })
            
            # Step 2: Merge Excel files into CSV
            print("\n📊 Step 2: Merging shoot schedules...")
            print("-" * 40)
            
            merge(output_dir, urls)
            print("✅ Files merged successfully")
            workflow_steps.append({
                'step': 'merge',
                'status': 'success'
            })
            
            # Step 3: Geocode addresses (Required for map functionality)
            print("\n🗺️ Step 3: Geocoding shoot locations...")
            print("-" * 40)
            
            # Geocode the data - required for map functionality in iOS app
            geocode_data(output_dir)
            print("✅ Geocoding completed")
            workflow_steps.append({
                'step': 'geocode',
                'status': 'success'
            })
            
            # Step 4: Load data into PostgreSQL
            print("\n🐘 Step 4: Loading data into PostgreSQL...")
            print("-" * 40)
            
            load_and_insert_data(output_dir)
            print("✅ Data loaded into PostgreSQL")
            workflow_steps.append({
                'step': 'postgres_load',
                'status': 'success'
            })
            
            # Step 5: Generate mobile database
            print("\n📱 Step 5: Generating mobile database...")
            print("-" * 40)
            
            # Generate the SQLite database
            generate_database()
            print("✅ Mobile database generated")
            workflow_steps.append({
                'step': 'generate_database',
                'status': 'success'
            })
            
            # Step 6: Upload to Firebase Storage
            print("\n☁️ Step 6: Uploading database to Firebase Storage...")
            print("-" * 40)
            
            # Upload the generated database
            # Check multiple locations for the database file
            database_locations = [
                "data/shoots.sqlite",
                "shoots.sqlite",
                "../data/shoots.sqlite",
                "../../data/shoots.sqlite"
            ]
            
            database_file = None
            for location in database_locations:
                if os.path.exists(location):
                    database_file = location
                    print(f"📍 Found database at: {location}")
                    break
            
            if database_file:
                public_url = upload_to_firebase(database_file)
                if public_url:
                    print("✅ Database uploaded to Firebase Storage")
                    workflow_steps.append({
                        'step': 'upload',
                        'status': 'success',
                        'url': public_url
                    })
                else:
                    print("❌ Failed to upload database")
                    workflow_steps.append({
                        'step': 'upload',
                        'status': 'failed'
                    })
            else:
                print("❌ Database file not found")
                workflow_steps.append({
                    'step': 'upload',
                    'status': 'failed',
                    'error': 'Database file not found'
                })
            
        else:
            print("ℹ️ No new files to process - schedules are up to date")
            workflow_steps.append({
                'step': 'download',
                'status': 'skipped',
                'reason': 'no_updates'
            })
            
            # Still deploy the database if forced via environment or parameter
            if os.getenv('FORCE_DEPLOY', 'false').lower() == 'true' or force:
                print("\n🔄 Force deploy requested...")
                
                # Generate and upload
                generate_database()
                
                # Look for database in multiple locations
                database_locations = ["data/shoots.sqlite", "shoots.sqlite", "../data/shoots.sqlite", "../../data/shoots.sqlite"]
                database_file = None
                for location in database_locations:
                    if os.path.exists(location):
                        database_file = location
                        break
                
                if database_file:
                    public_url = upload_to_firebase(database_file)
                    if public_url:
                        workflow_steps.append({
                            'step': 'force_deploy',
                            'status': 'success',
                            'forced': True,
                            'url': public_url
                        })
                    else:
                        workflow_steps.append({
                            'step': 'force_deploy',
                            'status': 'failed',
                            'forced': True
                        })
        
        # Calculate total time
        total_time = time.time() - start_time
        
        # Summary
        print("\n" + "=" * 60)
        print("✅ WORKFLOW COMPLETE!")
        print("=" * 60)
        print(f"⏱️ Total time: {total_time:.1f} seconds")
        print(f"📊 Steps completed: {len([s for s in workflow_steps if s.get('status') == 'success'])}")
        
        # Save workflow summary
        summary = {
            'timestamp': datetime.now().isoformat(),
            'duration_seconds': total_time,
            'steps': workflow_steps,
            'success': True
        }
        
        with open('workflow_summary.json', 'w') as f:
            json.dump(summary, f, indent=2)
        
        print(f"📄 Workflow summary saved to workflow_summary.json")
        
        return 0
        
    except Exception as e:
        print(f"\n❌ WORKFLOW FAILED: {e}")
        print(f"   Failed at step: {len(workflow_steps) + 1}")
        
        # Save error summary
        summary = {
            'timestamp': datetime.now().isoformat(),
            'duration_seconds': time.time() - start_time,
            'steps': workflow_steps,
            'error': str(e),
            'success': False
        }
        
        with open('workflow_summary.json', 'w') as f:
            json.dump(summary, f, indent=2)
        
        return 1

def main():
    """Main entry point."""
    
    # Parse command line arguments
    parser = argparse.ArgumentParser(
        description='Process shoot schedules and deploy mobile database'
    )
    parser.add_argument(
        '--force', 
        action='store_true',
        help='Force re-download and processing of all files, ignoring cache'
    )
    args = parser.parse_args()
    
    # Check for required environment variables
    required_vars = ['DATABASE_URL']
    missing_vars = [var for var in required_vars if not os.getenv(var)]
    
    if missing_vars:
        print(f"❌ Missing required environment variables: {', '.join(missing_vars)}")
        sys.exit(1)
    
    # Optional: Set up scheduled runs
    if os.getenv('RUN_SCHEDULE', 'once') == 'continuous':
        # Run every 6 hours
        import schedule
        
        print("🔄 Running in continuous mode (every 6 hours)")
        # Pass force flag to scheduled runs if needed
        schedule.every(6).hours.do(lambda: run_workflow(force=args.force))
        
        # Run immediately
        run_workflow(force=args.force)
        
        # Keep running
        while True:
            schedule.run_pending()
            time.sleep(60)  # Check every minute
    else:
        # Run once
        sys.exit(run_workflow(force=args.force))

if __name__ == "__main__":
    main()