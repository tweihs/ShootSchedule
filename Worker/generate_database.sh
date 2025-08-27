#!/bin/bash
# Generate SQLite database from PostgreSQL
# This script should be run from the Worker directory

echo "🗄️ ShootSchedule Database Generator"
echo "===================================="

# Check if we're in the Worker directory
if [ ! -f "requirements.txt" ]; then
    echo "❌ Error: This script must be run from the Worker directory"
    echo "   Current directory: $(pwd)"
    exit 1
fi

# Check for DATABASE_URL
if [ -z "$DATABASE_URL" ]; then
    echo "❌ Error: DATABASE_URL environment variable not set"
    echo "   Set it to your PostgreSQL connection string:"
    echo "   export DATABASE_URL='postgresql://user:pass@host:port/database'"
    exit 1
fi

# Create data directory if it doesn't exist
if [ ! -d "data" ]; then
    echo "📁 Creating data directory..."
    mkdir -p data
fi

echo "🔗 Database URL configured"
echo "📁 Output directory: data/"
echo ""

# Run the generation script
cd python/src
python generate_mobile_db.py "../../data/shoots.sqlite"

# Check if successful
if [ -f "../../data/shoots.sqlite" ]; then
    SIZE=$(du -h "../../data/shoots.sqlite" | cut -f1)
    echo ""
    echo "===================================="
    echo "✅ Database generated successfully!"
    echo "📄 File: data/shoots.sqlite"
    echo "💾 Size: $SIZE"
    echo ""
    echo "Next step: Run ./upload_database.sh to upload to Firebase"
else
    echo ""
    echo "❌ Failed to generate database"
    exit 1
fi