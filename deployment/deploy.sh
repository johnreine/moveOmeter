#!/bin/bash
# moveOmeter Dashboard Deployment Script
# Usage: ./deploy.sh user@host

set -e

if [ -z "$1" ]; then
    echo "Usage: ./deploy.sh user@droplet-ip"
    echo "Example: ./deploy.sh deploy@165.232.123.45"
    exit 1
fi

TARGET=$1
REMOTE_USER=$(echo $TARGET | cut -d'@' -f1)

echo "🚀 Deploying moveOmeter dashboard to $TARGET"

# Create temporary directory on remote
echo "📦 Preparing remote directory..."
ssh $TARGET "mkdir -p /tmp/moveometer-deploy"

# Upload files
echo "⬆️  Uploading dashboard files..."
scp -r ../web/dashboard/* $TARGET:/tmp/moveometer-deploy/

# Deploy on remote
echo "🔧 Installing on server..."
ssh $TARGET << 'ENDSSH'
    # Move files to web directory
    sudo mkdir -p /var/www/moveometer
    sudo cp -r /tmp/moveometer-deploy/* /var/www/moveometer/

    # Set permissions
    sudo chown -R www-data:www-data /var/www/moveometer
    sudo chmod -R 755 /var/www/moveometer

    # Reload nginx if it exists
    if command -v nginx &> /dev/null; then
        sudo systemctl reload nginx
        echo "✅ Nginx reloaded"
    fi

    # Cleanup
    rm -rf /tmp/moveometer-deploy

    echo "✅ Deployment complete!"
ENDSSH

echo ""
echo "🎉 Dashboard deployed successfully!"
echo "📍 Visit: http://$(echo $TARGET | cut -d'@' -f2)"
