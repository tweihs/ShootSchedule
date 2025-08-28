#!/bin/bash

# Test the ShootSchedule workflow locally
# This script activates the venv and runs the workflow

set -e  # Exit on error

echo "🚀 ShootSchedule Worker - Local Test Runner"
echo "=========================================="
echo ""

# Get the directory of this script
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

# Check if venv exists
if [ ! -d ".venv" ]; then
    echo "❌ Virtual environment not found at .venv"
    echo "   Creating virtual environment..."
    python3 -m venv .venv
fi

# Activate virtual environment
echo "📦 Activating virtual environment..."
source .venv/bin/activate

# Install/update requirements
echo "📚 Installing requirements..."
pip install -q --upgrade pip
pip install -q -r requirements.txt

# Check for .env file
if [ ! -f ".env" ]; then
    echo "⚠️  Warning: .env file not found"
    echo "   Create a .env file with:"
    echo "   DATABASE_URL=postgresql://..."
    exit 1
fi

# Load environment variables from .env
export $(grep -v '^#' .env | xargs)

# Check for Firebase credentials
if [ ! -f "serviceAccountKey.json" ] && [ -z "$FIREBASE_CREDENTIALS" ]; then
    echo "⚠️  Warning: No Firebase credentials found!"
    echo "   - serviceAccountKey.json not found"
    echo "   - FIREBASE_CREDENTIALS env var not set"
    echo "   The workflow will run but Firebase upload will fail."
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo ""
echo "✅ Environment ready"
echo "   Python: $(which python)"
echo "   DATABASE_URL: ${DATABASE_URL:0:50}..."
if [ -f "serviceAccountKey.json" ]; then
    echo "   Firebase: Using serviceAccountKey.json"
elif [ ! -z "$FIREBASE_CREDENTIALS" ]; then
    echo "   Firebase: Using FIREBASE_CREDENTIALS env var"
fi

echo ""
echo "🔄 Starting workflow..."
echo "------------------------"
echo ""

# Run the workflow
cd python/src
python process_and_deploy.py

# Deactivate virtual environment
deactivate

echo ""
echo "✅ Test complete!"