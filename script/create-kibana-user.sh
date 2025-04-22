#!/bin/bash

echo "Waiting for Elasticsearch to be ready..."
until curl -s -u elastic:admin http://elasticsearch:9200 >/dev/null; do
  sleep 1
done

echo "Checking if kibana_system_user exists..."
if curl -s -u elastic:admin http://elasticsearch:9200/_security/user/kibana_system_user | grep -q 'kibana_system_user'; then
  echo "User already exists. Skipping."
else
  echo "Creating kibana_system_user..."
  curl -X POST -u elastic:admin http://elasticsearch:9200/_security/user/kibana_system_user \
    -H "Content-Type: application/json" \
    -d '{
      "password": "kibana123",
      "roles": [ "kibana_system" ],
      "full_name": "Kibana System User",
      "enabled": true
    }'
fi
