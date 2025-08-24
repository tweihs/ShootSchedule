#!/bin/bash

# Get the directory of the script
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Ensure the python and data directories exist
if [ ! -d "$DIR/../python" ]; then
  echo "Error: ../python directory does not exist."
  exit 1
fi

if [ ! -d "$DIR/../python/data" ]; then
  echo "Error: ../pythin/data directory does not exist."
  exit 1
fi

# Build Docker image
docker build --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') -t clay-chaser-worker -f $DIR/../Dockerfile $DIR/..