#!/bin/sh

API_GATEWAY_URL="http://apigateway:8080/actuator/health"
CONFIG_FILE="/etc/nginx/conf.d/apigateway.conf"
RETRY_INTERVAL=5  # Check every 5 seconds
TIMEOUT=120       # Max wait time (2 minutes)

echo "Waiting for API Gateway at $API_GATEWAY_URL..."

start_time=$(date +%s)

while true; do
    curl --output /dev/null --silent --head --fail "$API_GATEWAY_URL" && break
    sleep "$RETRY_INTERVAL"

    # Timeout check
    current_time=$(date +%s)
    elapsed_time=$((current_time - start_time))
    if [ "$elapsed_time" -ge "$TIMEOUT" ]; then
        echo "Timeout! API Gateway did not start in time."
        exit 1
    fi
done

echo "API Gateway is UP! Adding to Nginx..."
cat <<EOF > $CONFIG_FILE
server {
    listen 443 ssl;
    server_name phungvip.io.vn;

    ssl_certificate /etc/letsencrypt/live/phungvip.io.vn/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/phungvip.io.vn/privkey.pem;

    location / {
        proxy_pass http://apigateway:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
}
EOF

echo "Reloading Nginx..."
nginx -s reload
