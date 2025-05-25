#!/bin/sh

API_GATEWAY_URL="http://apigateway:8080/actuator/health"
CONFIG_FILE="/etc/nginx/conf.d/apigateway.conf"
RETRY_INTERVAL=5  # Check every 5 seconds
TIMEOUT=120       # Max wait time (2 minutes)
LOG_FILE="/var/log/nginx-init.log"

# ✅ Remove old config before starting
if [ -f "$CONFIG_FILE" ]; then
    echo "$(date) - Removing existing Nginx config: \$CONFIG_FILE" 
    rm "$CONFIG_FILE"
fi

echo "$(date) - Waiting for API Gateway at \$API_GATEWAY_URL..." 

start_time=$(date +%s)

while true; do
    curl --output /dev/null --silent --head --fail "$API_GATEWAY_URL" && break
    sleep "$RETRY_INTERVAL"

    current_time=$(date +%s)
    elapsed_time=$((current_time - start_time))
    if [ "$elapsed_time" -ge "$TIMEOUT" ]; then
        echo "$(date) - Timeout! API Gateway did not start in time." 
        exit 1
    fi
done

echo "$(date) - API Gateway is UP! Adding to Nginx..." 

cat <<EOF > "$CONFIG_FILE"
server {
    listen 443 ssl;
    server_name appf4.io.vn;

    ssl_certificate /etc/letsencrypt/live/appf4.io.vn/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/appf4.io.vn/privkey.pem;

    location / {
        proxy_pass http://apigateway:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
}
    # 🔹 Kafdrop with Keycloak Authentication
server {
    listen 443 ssl;
    server_name kafdrop.appf4.io.vn;

    ssl_certificate /etc/letsencrypt/live/appf4.io.vn/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/appf4.io.vn/privkey.pem;

    resolver 8.8.8.8 ipv6=off;  # 🔹 Add this to fix the DNS issue

    location / {
        access_by_lua_block {
            local opts = {
                redirect_uri = "https://kafdrop.appf4.io.vn/oauth2/callback",
                discovery = "https://keycloak.appf4.io.vn/realms/jhipster/.well-known/openid-configuration",
                client_id = "web_app",
                client_secret = "",
                scope = "openid email profile",
                ssl_verify = "no"  -- Disable SSL verification if self-signed
            }
            local res, err = require("resty.openidc").authenticate(opts)
            if err then
                ngx.status = 403
                ngx.say(err)
                ngx.exit(ngx.HTTP_FORBIDDEN)
            end
        }

        proxy_pass http://kafdrop:9000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
    # 🔹 Consul with Keycloak Authentication
server {
    listen 443 ssl;
    server_name consul.appf4.io.vn;

    ssl_certificate /etc/letsencrypt/live/appf4.io.vn/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/appf4.io.vn/privkey.pem;

    resolver 8.8.8.8 ipv6=off;

    # Allow unauthenticated access to API endpoints
    location ~* ^/v1/ {
        proxy_pass http://consul:8500;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Authorization \$http_authorization;
    }

    location / {
        access_by_lua_block {
            local opts = {
                redirect_uri = "https://consul.appf4.io.vn/oauth2/callback",
                discovery = "https://keycloak.appf4.io.vn/realms/jhipster/.well-known/openid-configuration",
                client_id = "web_app",
                client_secret = "",
                scope = "openid email profile",
                ssl_verify = "no"
            }
            local res, err = require("resty.openidc").authenticate(opts)
            if err then 
                ngx.status = 403
                ngx.say(err)
                ngx.exit(ngx.HTTP_FORBIDDEN)
            end
        }

        proxy_pass http://consul:8500;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Authorization \$http_authorization;
    }
}

server {
    listen 443 ssl;
    server_name jenkins.appf4.io.vn;

    ssl_certificate /etc/letsencrypt/live/appf4.io.vn/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/appf4.io.vn/privkey.pem;

    resolver 8.8.8.8 ipv6=off;  # Add this to fix the DNS issue

    location / {
        access_by_lua_block {
            local opts = {
                redirect_uri = "https://jenkins.appf4.io.vn/oauth2/callback",
                discovery = "https://keycloak.appf4.io.vn/realms/jhipster/.well-known/openid-configuration",
                client_id = "web_app",
                client_secret = "",
                scope = "openid email profile",
                ssl_verify = "no"  -- Disable SSL verification if self-signed
            }
            local res, err = require("resty.openidc").authenticate(opts)
            if err then 
                ngx.status = 403
                ngx.say(err)
                ngx.exit(ngx.HTTP_FORBIDDEN)
            end
        }

        proxy_pass http://jenkins:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;  # Pass protocol info to Jenkins
    }
}


EOF

echo "$(date) - Validating Nginx configuration..." 
if nginx -t; then
    echo "$(date) - Configuration is valid. Reloading Nginx..." 
    nginx -s reload
else
    echo "$(date) - Nginx configuration is invalid! Check the config file." 
    exit 1
fi
