#!/bin/bash

# Container name
CONTAINER_NAME="clay-chaser-worker"

# Check if the container exists and remove it if necessary
if [ "$(docker ps -a -q -f name=$CONTAINER_NAME)" ]; then
    echo "Stopping and removing existing container..."
    docker stop $CONTAINER_NAME
    docker rm $CONTAINER_NAME
fi

## Run the Docker container locally
docker run -d --name $CONTAINER_NAME -p 8000:8000 $CONTAINER_NAME

# Optional: Print message to check logs
echo "Container started in detached mode. To check logs, use: docker logs -f $CONTAINER_NAME"

docker logs -f $CONTAINER_NAME