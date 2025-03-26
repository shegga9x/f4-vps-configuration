#!/bin/bash

# Define services
SERVICES=("shegga/apigateway" "tuongtran1345/msmedia")

# Track updated services
UPDATED_SERVICES=()

check_and_update() {
    local SERVICE=$1
    echo "Checking updates for: $SERVICE"

    # Get current running container ID (if running)
    CONTAINER_ID=$(docker ps -q --filter "ancestor=$SERVICE")

    if [ -n "$CONTAINER_ID" ]; then
        CURRENT_ID=$(docker inspect --format='{{.Image}}' "$CONTAINER_ID" 2>/dev/null)
    else
        echo "⚠️  Service $SERVICE is not running. Pulling latest image..."
        CURRENT_ID=""
    fi

    # Pull the latest image
    docker pull $SERVICE > /dev/null 2>&1
    echo "🔄 Pulled latest image for $SERVICE"

    # Get the latest image ID
    LATEST_ID=$(docker images --no-trunc --format "{{.ID}}" $SERVICE | head -n 1)

    # Compare image IDs
    if [ "$CURRENT_ID" != "$LATEST_ID" ]; then
        echo "✅ New image detected for $SERVICE! Marking for redeployment."
        UPDATED_SERVICES+=("$SERVICE")
    else
        echo "ℹ️  No updates for $SERVICE."
    fi
}

# Check all services
for SERVICE in "${SERVICES[@]}"; do
    check_and_update "$SERVICE"
done

# Restart only updated services
if [ ${#UPDATED_SERVICES[@]} -gt 0 ]; then
    echo "🚀 Redeploying updated services..."
    
    # Check if docker-compose file exists
    COMPOSE_FILE="/var/jenkins_home/project/docker-compose.yml"
    if [ ! -f "$COMPOSE_FILE" ]; then
        echo "❌ ERROR: docker-compose.yml not found at $COMPOSE_FILE"
        exit 1
    fi

    cd /var/jenkins_home/project

    for SERVICE in "${UPDATED_SERVICES[@]}"; do
        SERVICE_NAME=$(echo $SERVICE | awk -F'/' '{print $2}')
        echo "🔄 Restarting $SERVICE_NAME..."
        docker-compose up -d --no-deps --force-recreate $SERVICE_NAME
    done
else
    echo "✅ No services needed redeployment."
fi
