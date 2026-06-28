#!/bin/bash
set -e

DOMAIN="edushamiitapi.shamiit.com"
EMAIL="webmaster@shamiit.com"
CERT_DIR="/etc/letsencrypt/live/$DOMAIN"

echo "=== Starting SSL Setup for $DOMAIN ==="

# 1. Install certbot if not already installed
if ! command -v certbot &> /dev/null; then
    echo "Installing certbot..."
    sudo apt-get update
    sudo apt-get install -y certbot
fi

# 2. Check if certificates directory exists
if [ ! -f "$CERT_DIR/fullchain.pem" ]; then
    echo "SSL Certificate not found. Generating temporary self-signed certificate so Nginx can start..."
    sudo mkdir -p "$CERT_DIR"
    sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$CERT_DIR/privkey.pem" \
        -out "$CERT_DIR/fullchain.pem" \
        -subj "/CN=$DOMAIN"
    echo "Self-signed certificate created."
fi

# 3. Make sure Nginx is stopped to release port 80 for Certbot
echo "Stopping Nginx to request Let's Encrypt certificates..."
cd /app
sudo docker compose stop nginx || true

echo "Requesting Let's Encrypt SSL certificate..."
if sudo certbot certonly --standalone \
    -d "$DOMAIN" \
    --non-interactive \
    --agree-tos \
    --email "$EMAIL" \
    --keep-until-expiring \
    --preferred-challenges http; then
    echo "Let's Encrypt certificate obtained successfully!"
else
    echo "WARNING: Let's Encrypt request failed. This usually means DNS has not propagated yet."
    echo "We will fall back to using the self-signed certificate for now."
    echo "Ensure your DNS A-record for $DOMAIN points to this VM's IP, and rerun this script later."
fi

# 4. Restart all services
echo "Relaunching all services in Docker..."
sudo docker compose down
sudo find /app -name "*.sh" -exec chmod +x {} +
sudo docker compose up -d

echo "=== SSL Setup Completed ==="
