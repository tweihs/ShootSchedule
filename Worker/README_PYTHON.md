# ShootSchedule Worker Scripts

Python scripts for processing shoot schedule data and deploying to Firebase Storage.

## Setup

### 1. Install Dependencies

```bash
pip install -r requirements.txt
```

### 2. Get Firebase Service Account Key

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project (shootsdb-11bb7)
3. Go to Project Settings → Service Accounts
4. Click "Generate New Private Key"
5. Save the JSON file as `serviceAccountKey.json`

### 3. Set Environment Variables

```bash
# Required for database operations
export DATABASE_URL="postgresql://user:pass@host:port/database"

# Required for Firebase upload
export GOOGLE_APPLICATION_CREDENTIALS="path/to/serviceAccountKey.json"
export FIREBASE_STORAGE_BUCKET="shootsdb-11bb7.firebasestorage.app"
```

## Scripts

### UploadSqliteToCloud.py

Standalone script to upload SQLite database to Firebase Storage.

```bash
# Basic usage
python UploadSqliteToCloud.py shoots.sqlite

# With custom credentials
python UploadSqliteToCloud.py shoots.sqlite --credentials ~/keys/firebase-key.json

# With custom bucket
python UploadSqliteToCloud.py shoots.sqlite --bucket my-app.appspot.com

# Verify before upload
python UploadSqliteToCloud.py shoots.sqlite --verify
```

### test_upload.py

Test the Firebase upload with a small test database.

```bash
# Test upload (creates small test database)
python test_upload.py --credentials serviceAccountKey.json

# Keep test file after upload
python test_upload.py --credentials serviceAccountKey.json --keep
```

### generate_mobile_db.py

Generate SQLite database from PostgreSQL.

```bash
# Generate shoots.sqlite from PostgreSQL
python generate_mobile_db.py

# Generate with custom output name
python generate_mobile_db.py custom.sqlite
```

### process_and_deploy.py

Complete workflow: download Excel → merge → geocode → PostgreSQL → SQLite → Firebase.

```bash
# Run complete workflow
python process_and_deploy.py

# Force deployment even if no updates
FORCE_DEPLOY=true python process_and_deploy.py

# Run continuously (every 6 hours)
RUN_SCHEDULE=continuous python process_and_deploy.py
```

## Individual Processing Scripts

### DownloadShootFilesWithLastModified.py

Download Excel files from NSSA/NSCA with caching.

```bash
python DownloadShootFilesWithLastModified.py
```

### MergeShootData.py

Merge Excel files into combined CSV.

```bash
python MergeShootData.py
```

### GeocodeEventData.py

Geocode shoot locations using club addresses.

```bash
python GeocodeEventData.py
```

### CreatePostgresLoadScript.py

Load geocoded data into PostgreSQL.

```bash
python CreatePostgresLoadScript.py
```

### CreateSqliteWithWeather.py

Create SQLite with weather estimates.

```bash
python CreateSqliteWithWeather.py
```

## Workflow

### Manual Step-by-Step

```bash
# 1. Download latest Excel files
python DownloadShootFilesWithLastModified.py

# 2. Merge into combined CSV
python MergeShootData.py

# 3. Geocode locations
python GeocodeEventData.py

# 4. Load into PostgreSQL
python CreatePostgresLoadScript.py

# 5. Generate SQLite database
python generate_mobile_db.py

# 6. Upload to Firebase
python UploadSqliteToCloud.py shoots.sqlite
```

### Automated Workflow

```bash
# Run complete workflow
python process_and_deploy.py
```

## Deployment to Heroku

See [heroku_config.md](../heroku_config.md) for detailed Heroku deployment instructions.

Quick setup:

```bash
# Create app
heroku create shootschedule-worker

# Set to container stack
heroku stack:set container

# Set environment variables
heroku config:set DATABASE_URL="your-postgres-url"
heroku config:set STORAGE_TYPE="FIREBASE"
heroku config:set FIREBASE_STORAGE_BUCKET="shootsdb-11bb7.firebasestorage.app"

# Add Firebase credentials (get JSON from Firebase Console)
heroku config:set GOOGLE_CREDENTIALS="$(cat serviceAccountKey.json | jq -c .)"

# Deploy
git push heroku main

# Schedule to run every 6 hours
heroku addons:create scheduler:standard
# Add job: python process_and_deploy.py
```

## Testing

### Test Database Connection

```bash
python -c "from CreateSqlite import postgres_to_sqlite; postgres_to_sqlite('test.sqlite')"
```

### Test Firebase Upload

```bash
python test_upload.py --credentials serviceAccountKey.json
```

### Verify Upload

The uploaded database will be available at:
```
https://firebasestorage.googleapis.com/v0/b/shootsdb-11bb7.firebasestorage.app/o/shoots.sqlite?alt=media
```

## Troubleshooting

### Firebase Authentication Error

If you see "No Firebase credentials found":
1. Check GOOGLE_APPLICATION_CREDENTIALS environment variable
2. Verify serviceAccountKey.json exists and is valid
3. Ensure the service account has Storage Admin role

### Database Connection Error

If PostgreSQL connection fails:
1. Check DATABASE_URL format: `postgresql://user:pass@host:port/database`
2. Verify database is accessible from your network
3. Check SSL requirements (may need `?sslmode=require`)

### Upload Fails

If upload fails:
1. Check internet connection
2. Verify Firebase Storage bucket name
3. Ensure service account has proper permissions
4. Check if file exists and is valid SQLite

## iOS App Integration

The iOS app downloads from:
```swift
private let databaseURL = "https://firebasestorage.googleapis.com/v0/b/shootsdb-11bb7.firebasestorage.app/o/shoots.sqlite?alt=media"
```

The app uses HTTP headers (Last-Modified, ETag) to check for updates efficiently.