#!/bin/bash
# Upload database to Firebase Storage
# This script should be run from the Worker directory

echo "🚀 ShootSchedule Database Upload"
echo "================================"

# Check if we're in the Worker directory
if [ ! -f "requirements.txt" ]; then
    echo "❌ Error: This script must be run from the Worker directory"
    echo "   Current directory: $(pwd)"
    exit 1
fi

# Check for service account key
if [ ! -f "serviceAccountKey.json" ]; then
    echo "❌ Error: serviceAccountKey.json not found in Worker directory"
    echo "   Please download from Firebase Console and place in this directory"
    exit 1
fi

# Check for database file
DATABASE_FILE=""
if [ -f "data/shoots.sqlite" ]; then
    DATABASE_FILE="data/shoots.sqlite"
elif [ -f "shoots.sqlite" ]; then
    DATABASE_FILE="shoots.sqlite"
else
    echo "❌ Error: No database file found"
    echo "   Checked: data/shoots.sqlite and shoots.sqlite"
    echo "   Run generate_database.sh first to create the database"
    exit 1
fi

echo "📱 Found database: $DATABASE_FILE"
echo "🔑 Found credentials: serviceAccountKey.json"
echo ""

# Set environment variable for credentials
export GOOGLE_APPLICATION_CREDENTIALS="serviceAccountKey.json"

# Run the upload script
cd python/src
python UploadSqliteToCloud.py "../../$DATABASE_FILE" --credentials "../../serviceAccountKey.json"

echo ""
echo "================================"
echo "✅ Upload complete!"