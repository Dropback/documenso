if [ "$PWD" != "$HOME/documenso" ]; then
  cd "$HOME/documenso"
fi

#!/bin/bash

# Configuration
IMAGE_NAME=" dropbackhq/documenso-dropback"
IMAGE_TAG="amd64:latest"

# Function to get image SHA
get_image_sha() {
    docker manifest inspect "${IMAGE_NAME}:${IMAGE_TAG}" 2>/dev/null | jq -r '.config.digest'
}

# Get remote SHA
REMOTE_SHA=$(get_image_sha)

# If we couldn't get remote SHA, exit
if [ -z "$REMOTE_SHA" ]; then
    echo "Could not get remote image SHA. Image might not exist in registry."
    exit 1
fi

# Get local SHA
LOCAL_SHA=$(docker inspect --format='{{.Id}}' "${IMAGE_NAME}:${IMAGE_TAG}" 2>/dev/null)

# If images are different or local image doesn't exist
if [ "$REMOTE_SHA" != "$LOCAL_SHA" ]; then
    echo "New image available. Pulling and restarting..."
    
    # Pull the new image
    docker-compose pull
    
    # Restart the container
    docker-compose down
    docker-compose up -d
    
    echo "Container restarted with new image"
else
    echo "Local image is up to date. No restart needed."
fi