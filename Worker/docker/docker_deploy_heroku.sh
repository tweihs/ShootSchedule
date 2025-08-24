#!/bin/bash

# Get the directory of the script
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Variables
APP_NAME="clay-chaser"
CONTAINER_NAME="clay-chaser-worker"
HEROKU_EMAIL="tyson@weihs.com"
HEROKU_API_KEY="14e845c0-7653-4474-9c63-d71c45b8693e"  # Replace with your Heroku API key

# Login to Heroku
#echo "Logging in to Heroku..."
#heroku auth:token <<< "$HEROKU_API_KEY"

# Create Heroku app (if it doesn't exist)
#echo "Creating Heroku app (if it doesn't exist)..."
#heroku create $APP_NAME || echo "App $APP_NAME already exists, proceeding..."

# Build the Docker image locally
#echo "Building Docker image locally..."
#docker build -t $APP_NAME -f $DIR/../Dockerfile.worker $DIR/..

# Login to Heroku Container
docker login --username=_ --password=$(heroku auth:token) registry.heroku.com

# Tag the image for Heroku
echo "Tagging image for Heroku..."
docker tag $CONTAINER_NAME registry.heroku.com/$APP_NAME/worker

# Log in to heroku container
# heroku container:login

# Push the Docker image to Heroku
echo "Pushing Docker image to Heroku..."
docker push registry.heroku.com/$APP_NAME/worker

# Release the Docker image
echo "Releasing the Docker image..."
heroku container:release worker

# Check logs to ensure everything is working correctly
echo "Checking logs..."
heroku logs --tail --app $APP_NAME