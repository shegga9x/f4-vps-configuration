docker run --rm -p 80:80 -p 443:443 \
  -v $(pwd)/nginx/letsencrypt:/etc/letsencrypt \
  certbot/certbot certonly --standalone \
  -d appf4.io.vn -d kafdrop.appf4.io.vn -d consul.appf4.io.vn -d keycloak.appf4.io.vn \
  -d kafka.appf4.io.vn \
  -d mysql.appf4.io.vn \
  -d redis.appf4.io.vn \
  --email shegga9x@gmail.com --agree-tos --non-interactive --no-eff-email