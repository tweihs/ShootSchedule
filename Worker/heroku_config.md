# Heroku Configuration for ShootSchedule Worker

## Environment Variables Required

Set these environment variables in Heroku:

```bash
# Database connection
heroku config:set DATABASE_URL="postgresql://username:password@host:port/database"

# Storage configuration (choose one)
heroku config:set STORAGE_TYPE="S3"  # or "FIREBASE" or "GCS"

# For S3 (if using AWS)
heroku config:set AWS_ACCESS_KEY_ID="your-access-key"
heroku config:set AWS_SECRET_ACCESS_KEY="your-secret-key"
heroku config:set S3_BUCKET="shootschedule-mobile"
heroku config:set S3_REGION="us-east-1"
heroku config:set S3_KEY="databases/shoots.sqlite"
heroku config:set CDN_URL="https://shootschedule-mobile.s3.amazonaws.com"

# For Firebase Storage (RECOMMENDED)
heroku config:set STORAGE_TYPE="FIREBASE"
heroku config:set FIREBASE_STORAGE_BUCKET="shootsdb-11bb7.firebasestorage.app"
# You'll need to add service account credentials as a buildpack env var
# Or use Google Cloud buildpack for Application Default Credentials

# For Google Cloud Storage (if using GCS)
heroku config:set GOOGLE_APPLICATION_CREDENTIALS="path/to/credentials.json"
heroku config:set GCS_BUCKET="shootschedule-mobile"

# Optional settings
heroku config:set INCLUDE_WEATHER="true"
heroku config:set DATABASE_VERSION="1.0"
heroku config:set FORCE_DEPLOY="false"
heroku config:set RUN_SCHEDULE="once"  # or "continuous" for scheduled runs
heroku config:set DEPLOYMENT_WEBHOOK_URL="https://your-webhook-url.com/notify"
```

## Deployment

### Initial Setup

1. Create a new Heroku app:
```bash
heroku create shootschedule-worker
```

2. Set the stack to container:
```bash
heroku stack:set container
```

3. Configure environment variables (see above)

4. Deploy:
```bash
git push heroku main
```

### Schedule Regular Runs

Option 1: Use Heroku Scheduler (recommended for periodic runs):
```bash
heroku addons:create scheduler:standard
heroku addons:open scheduler

# Add job: python process_and_deploy.py
# Frequency: Every 6 hours
```

Option 2: Use continuous mode:
```bash
heroku config:set RUN_SCHEDULE="continuous"
heroku ps:scale worker=1
```

## Setting up Firebase Service Account on Heroku

To authenticate with Firebase Storage from Heroku:

1. **Get Service Account Key from Firebase Console:**
   - Go to Firebase Console → Project Settings → Service Accounts
   - Click "Generate New Private Key"
   - Save the JSON file

2. **Add to Heroku as Config Var:**
   ```bash
   # Convert the JSON to a single line and set as config var
   heroku config:set GOOGLE_CREDENTIALS="$(cat path/to/serviceAccountKey.json | jq -c .)"
   ```

3. **Update deploy_mobile_db.py to use the credentials:**
   The script will automatically use these credentials when available.

## Database URLs

The deployed SQLite database will be available at:

### S3:
- Database: `https://shootschedule-mobile.s3.amazonaws.com/databases/shoots.sqlite`
- Manifest: `https://shootschedule-mobile.s3.amazonaws.com/databases/shoots_manifest.json`

### Firebase Storage (Current Production):
- Database: `https://firebasestorage.googleapis.com/v0/b/shootsdb-11bb7.firebasestorage.app/o/shoots.sqlite?alt=media`
- Direct GCS URL: `https://storage.googleapis.com/shootsdb-11bb7.firebasestorage.app/shoots.sqlite`

### Google Cloud Storage:
- Database: `https://storage.googleapis.com/{bucket}/databases/shoots.sqlite`
- Manifest: `https://storage.googleapis.com/{bucket}/databases/shoots_manifest.json`

## iOS App Configuration

In the iOS app, update the database URL:

```swift
// In SQLiteService.swift
private let databaseURL = "https://shootschedule-mobile.s3.amazonaws.com/databases/shoots.sqlite"
private let manifestURL = "https://shootschedule-mobile.s3.amazonaws.com/databases/shoots_manifest.json"
```

## Monitoring

View logs:
```bash
heroku logs --tail
```

Check worker status:
```bash
heroku ps
```

## Manifest File Format

The manifest file contains metadata about the database:

```json
{
  "last_modified": "2024-01-27T12:00:00Z",
  "file_hash": "sha256-hash-of-file",
  "file_size": 5242880,
  "file_size_mb": 5.0,
  "database_version": "1.0",
  "shoot_count": 1234,
  "generated_at": "2024-01-27T12:00:00Z",
  "includes_weather": true,
  "download_url": "https://...",
  "manifest_url": "https://..."
}
```

The iOS app can check the manifest first to determine if a new database needs to be downloaded by comparing the `last_modified` or `file_hash` values.