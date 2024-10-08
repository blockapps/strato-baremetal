#!/bin/bash
set -e

if [ "$#" -ne 2 ]; then
    echo "The scripts expects 2 arguments: the domain name and the email address. For example: ./ssl-get-cert.sh example.com me@example.com"
    exit 101
fi

if [ ! -d "/datadrive/strato-getting-started" ]; then
  echo "Expected to have strato-getting-started at /datadrive/strato-getting-started, but the directory does not exist."
  exit 102
fi

DOMAIN=$1
EMAIL=$2

# Ignoring the existing certs if they exists
rm -rf /tmp/letsencrypt && mv /etc/letsencrypt /tmp/
sudo certbot certonly --standalone --preferred-challenges http --agree-tos --non-interactive --email "${EMAIL}" -d "${DOMAIN}"

sudo cp /etc/letsencrypt/live/${DOMAIN}/fullchain.pem /datadrive/strato-getting-started/ssl/certs/server.pem
sudo cp /etc/letsencrypt/live/${DOMAIN}/privkey.pem /datadrive/strato-getting-started/ssl/private/server.key

if [ "$(docker ps -a --filter name=strato-nginx-1 --format '{{.Names}}')" = "strato-nginx-1" ]; then
  sudo docker cp --follow-link /datadrive/strato-getting-started/ssl/certs/server.pem strato-nginx-1:/etc/ssl/certs/server.pem
  sudo docker cp --follow-link /datadrive/strato-getting-started/ssl/private/server.key strato-nginx-1:/etc/ssl/private/server.key
  sudo docker exec strato-nginx-1 openresty -s reload
  echo "Cert updated for the running node."
else
  echo "No strato-nginx-1 container is running. STRATO is not yet started. Skipping the cert update for the running node."
fi
