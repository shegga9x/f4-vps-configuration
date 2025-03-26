docker run --rm -p 80:80 -p 443:443 \
  -v $(pwd)/nginx/letsencrypt:/etc/letsencrypt \
  certbot/certbot certonly --standalone \
  -d phungvip.io.vn -d kafdrop.phungvip.io.vn -d consul.phungvip.io.vn -d keycloak.phungvip.io.vn \
  --email shegga9x@gmail.com --agree-tos --non-interactive --no-eff-email