#!/bin/bash

# Keycloak Configuration
KEYCLOAK_REALM="jhipster"
KEYCLOAK_URL="https://keycloak. appf4s.io.vn"
KEYCLOAK_TOKEN_URL="${KEYCLOAK_URL}/realms/${KEYCLOAK_REALM}/protocol/openid-connect/token"

# Client ID
CLIENT_ID="web_app" # Set your client ID here

# Public User Credentials
USERNAME="admin" # Replace with your public username
PASSWORD="admin"   # Replace with your public password

# Request the token using curl
# Ensure curl and jq are installed (e.g., sudo apt update && sudo apt install -y curl jq)
TOKEN_RESPONSE=$(curl -s -X POST "${KEYCLOAK_TOKEN_URL}" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=${CLIENT_ID}" \
  -d "username=${USERNAME}" \
  -d "password=${PASSWORD}" \
  -d "grant_type=password" \
  -d "scope=openid")

# Extract the access token using jq
ACCESS_TOKEN=$(echo "${TOKEN_RESPONSE}" | jq -r '.access_token')

# Check if token was obtained successfully
if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" == "null" ]; then
  echo "Error: Failed to obtain access token from Keycloak." >&2
  echo "Response: ${TOKEN_RESPONSE}" >&2
  exit 1
fi

# Output the access token so it can be captured
echo "Access Token: ${ACCESS_TOKEN}"

# Update the docker-compose file with the access token
DOCKER_COMPOSE_FILE="docker-compose.remoteApigateway.yml"
sed -i.bak "s|SPRING_CLOUD_CONSUL_CONFIG_HEADERS_Authorization=Bearer <PASTE_TOKEN_HERE>|SPRING_CLOUD_CONSUL_CONFIG_HEADERS_Authorization=Bearer ${ACCESS_TOKEN}|" "$DOCKER_COMPOSE_FILE"

# Run docker-compose
docker compose -f "$DOCKER_COMPOSE_FILE" up -d --force-recreate remote-apigateway

# Optional: Clean up the backup file created by sed
# rm "${DOCKER_COMPOSE_FILE}.bak"
