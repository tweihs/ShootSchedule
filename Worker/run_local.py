#!/usr/bin/env python3
"""
Local test runner for the ShootSchedule workflow.
Run this from the project root directory.
"""

import os
import sys
from pathlib import Path

# Add python/src to path so we can import the modules
project_root = Path(__file__).parent
sys.path.insert(0, str(project_root / "python" / "src"))

# Load environment variables from .env file
from dotenv import load_dotenv
load_dotenv()

# Verify required environment variables
required_vars = ['DATABASE_URL']
missing_vars = [var for var in required_vars if not os.getenv(var)]

if missing_vars:
    print(f"❌ Missing required environment variables: {', '.join(missing_vars)}")
    print("\nMake sure your .env file or IntelliJ run configuration includes:")
    print("  DATABASE_URL=postgresql://...")
    print("\nOptional variables:")
    print("  FORCE_DEPLOY=true  # Force upload even if no changes")
    print("  RUN_SCHEDULE=once  # or 'continuous' for repeated runs")
    sys.exit(1)

# Check for Firebase credentials
if not os.path.exists('serviceAccountKey.json') and not os.getenv('FIREBASE_CREDENTIALS'):
    print("⚠️  Warning: No Firebase credentials found!")
    print("   - serviceAccountKey.json not found in project root")
    print("   - FIREBASE_CREDENTIALS environment variable not set")
    print("   The workflow will run but Firebase upload will fail.")
    response = input("\nContinue anyway? (y/N): ")
    if response.lower() != 'y':
        sys.exit(1)

print("✅ Environment configured")
print(f"   DATABASE_URL: {os.getenv('DATABASE_URL')[:50]}...")
if os.path.exists('serviceAccountKey.json'):
    print("   Firebase: Using serviceAccountKey.json")
elif os.getenv('FIREBASE_CREDENTIALS'):
    print("   Firebase: Using FIREBASE_CREDENTIALS env var")
print()

# Import and run the workflow
try:
    from process_and_deploy import run_workflow
    print("Starting workflow...\n")
    exit_code = run_workflow()
    sys.exit(exit_code)
except ImportError as e:
    print(f"❌ Failed to import workflow: {e}")
    print("Make sure you're running from the project root directory")
    sys.exit(1)
except Exception as e:
    print(f"❌ Workflow failed: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)