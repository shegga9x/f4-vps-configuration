docker run --rm -p 80:80 -p 443:443 \
  -v $(pwd)/nginx/letsencrypt:/etc/letsencrypt \
  certbot/certbot certonly --standalone \
  -d appf4.io.vn -d kafdrop.appf4.io.vn -d consul.appf4.io.vn -d keycloak.appf4.io.vn \
  -d kafka.appf4.io.vn \
  -d mysql.appf4.io.vn \
  -d redis.appf4.io.vn \
  -d redisinsiight.appf4.io.vn \
  --email shegga9x@gmail.com --agree-tos --non-interactive --no-eff-email


mkdir -p kafka/ssl

# Generate Keystore
keytool -genkey -alias kafka-server \
  -keyalg RSA \
  -keystore kafka.server.keystore.jks \
  -storepass f4security \
  -keypass f4security \
  -dname "CN=appf4.io.vn"

# Export Certificate
keytool -export -alias kafka-server \
  -file kafka-server-cert \
  -keystore kafka.server.keystore.jks \
  -storepass f4security

# Create Truststore
keytool -import -alias kafka-server \
  -file kafka-server-cert \
  -keystore kafka.server.truststore.jks \
  -storepass f4security \
  -noprompt

# Create credentials files
echo f4security > kafka/ssl/keystore_creds
echo f4security > kafka/ssl/key_creds
echo f4security > kafka/ssl/truststore_creds

# Move keystore/truststore
mv kafka.server.keystore.jks kafka/ssl/
mv kafka.server.truststore.jks kafka/ssl/
rm kafka-server-cert


ssh -R 8085:localhost:8084 -R 8083:localhost:8081 root@68.183.189.152