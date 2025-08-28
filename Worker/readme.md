# ShootSchedule Worker

## Overview
The ShootSchedule Worker is a Heroku-deployed Python container that automatically processes shooting event data and deploys it to Firebase Storage for the iOS app to consume. Previously known as ClayChaser or ShootsDB, this worker runs on a schedule to keep the mobile database up-to-date.

## Architecture

### Heroku Setup
- **App Name**: `shootsdb-worker`
- **Stack**: Container (Docker-based)
- **Dyno Type**: Worker (not web)
- **Database**: PostgreSQL Essential-0 addon
- **Region**: US

### Container Configuration
The worker uses Docker with automatic builds triggered by git pushes to Heroku. The container:
- Runs Python 3
- Installs PostgreSQL libraries
- Includes cached Club_Locations.csv for geocoding
- Executes `process_and_deploy.py` on startup

## Workflow Process

The worker executes the following pipeline (`python/src/process_and_deploy.py`):

1. **Download** - Fetches Excel files from www.nssa-nsca.org
   - NSSA and NSCA shoot schedules for current year
   - Checks Last-Modified headers to avoid unnecessary downloads

2. **Merge** - Combines Excel files into a unified CSV format

3. **Geocode** - Converts addresses to lat/lon coordinates
   - Uses cached `Club_Locations.csv` to minimize API calls
   - Required for map functionality in the iOS app

4. **Load** - Imports data into PostgreSQL database

5. **Generate** - Creates optimized SQLite database for mobile

6. **Upload** - Deploys SQLite file to Firebase Storage
   - iOS app downloads this file for offline use

## Deployment

### Method 1: Git Push (Recommended)
Since `heroku.yml` is configured and the stack is set to `container`, deployment is automatic:

```bash
# From Worker directory
cd /path/to/ShootSchedule/Worker

# Add and commit changes
git add .
git commit -m "Update worker process"

# Deploy to Heroku (triggers Docker build)
git push heroku main

# Monitor deployment
heroku logs --tail -a shootsdb-worker
```

### Method 2: Container Registry (Alternative)
```bash
# Build and push container directly
heroku container:push worker -a shootsdb-worker
heroku container:release worker -a shootsdb-worker
```

## Environment Variables

Required environment variables on Heroku:

```bash
# Database (automatically set by PostgreSQL addon)
DATABASE_URL=postgresql://...

# Firebase Service Account (for cloud storage upload)
FIREBASE_CREDENTIALS='{"type": "service_account", ...}'

# Optional: Force deployment even if no data changes
FORCE_DEPLOY=true

# Optional: Run continuously vs once
RUN_SCHEDULE=once  # or 'continuous' for every 6 hours
```

## Setting Up Firebase Credentials

### Option 1: Environment Variable (Recommended for Heroku)
```bash
# Get your service account JSON from Firebase Console
# Firebase Console > Project Settings > Service Accounts > Generate New Private Key

# Set as environment variable (escape the JSON properly)
heroku config:set FIREBASE_CREDENTIALS='{"type":"service_account","project_id":"shootsdb-11bb7",...}' -a shootsdb-worker
```

### Option 2: File-based (for local testing)
Place `serviceAccountKey.json` in the Worker directory. The code checks both methods.

## File Structure

```
Worker/
├── Dockerfile              # Container definition
├── heroku.yml             # Heroku container configuration
├── requirements.txt       # Python dependencies
├── python/
│   └── src/
│       ├── process_and_deploy.py     # Main orchestrator
│       ├── DownloadShootFilesWithLastModified.py
│       ├── MergeShootData.py
│       ├── GeocodeEventData.py
│       ├── CreatePostgresLoadScript.py
│       ├── generate_mobile_db.py
│       └── UploadSqliteToCloud.py    # Firebase Storage upload
├── data/
│   └── Club_Locations.csv           # Cached geocoding data
└── docker/
    ├── docker_build.sh              # Local build script
    ├── docker_run.sh                # Local run script
    └── docker_deploy_heroku.sh     # Manual deploy (deprecated)
```

## Local Development

### Testing Locally with Docker
```bash
# Build container
./docker/docker_build.sh

# Run locally (requires .env file with DATABASE_URL)
./docker/docker_run.sh
```

### Testing Without Docker
```bash
# Set up Python environment
python -m venv venv
source venv/bin/activate  # or venv\Scripts\activate on Windows
pip install -r requirements.txt

# Set environment variables
export DATABASE_URL="your_postgres_url"
export FIREBASE_CREDENTIALS='{"type":"service_account",...}'

# Run workflow
cd python/src
python process_and_deploy.py
```

## Monitoring

```bash
# View logs
heroku logs --tail -a shootsdb-worker

# Check dyno status
heroku ps -a shootsdb-worker

# Scale dynos (0 to stop, 1 to start)
heroku ps:scale worker=0 -a shootsdb-worker
heroku ps:scale worker=1 -a shootsdb-worker

# Run one-off command
heroku run python python/src/process_and_deploy.py -a shootsdb-worker
```

## Troubleshooting

### Database Connection Issues
- Verify DATABASE_URL is set: `heroku config -a shootsdb-worker`
- Check PostgreSQL addon status: `heroku addons -a shootsdb-worker`

### Firebase Upload Failures
- Verify FIREBASE_CREDENTIALS is properly set
- Check Firebase Storage bucket permissions
- Ensure service account has Storage Admin role

### Container Build Failures
- Check Dockerfile syntax
- Verify all required files are committed to git
- Review build logs: `heroku logs --tail -a shootsdb-worker`

## Legacy Notes
- Previously named "ClayChaser" and "ShootsDB"
- The deployment method in Heroku used for the app is CLI
- Because a Dockerfile is present, Heroku builds the container and runs it automatically