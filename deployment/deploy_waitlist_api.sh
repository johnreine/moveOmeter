#!/bin/bash
# Deploy waitlist API to server

set -e

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

echo "=== Waitlist API Deployment ==="
echo ""

# Check for environment variables
if [ -z "$RESEND_API_KEY" ]; then
  echo "❌ Error: RESEND_API_KEY not set"
  echo "Please set it: export RESEND_API_KEY='your_key_here'"
  exit 1
fi

if [ -z "$RESEND_AUDIENCE_ID" ]; then
  echo "❌ Error: RESEND_AUDIENCE_ID not set"
  echo "Please set it: export RESEND_AUDIENCE_ID='your_audience_id_here'"
  exit 1
fi

echo "📦 Step 1: Installing Node.js on server..."
ssh ${DEPLOY_TARGET} "command -v node >/dev/null 2>&1 || (curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && apt-get install -y nodejs)"
echo "✅ Node.js installed"
echo ""

echo "📁 Step 2: Creating API directory..."
ssh ${DEPLOY_TARGET} "mkdir -p ${REMOTE_WEB_DIR}/api"
echo "✅ Directory created"
echo ""

echo "📄 Step 3: Copying API files..."
scp "${SCRIPT_DIR}/../web/api/waitlist.js" ${DEPLOY_TARGET}:${REMOTE_WEB_DIR}/api/
echo "✅ API files copied"
echo ""

echo "🔐 Step 4: Creating environment file..."
ssh ${DEPLOY_TARGET} "cat > ${REMOTE_WEB_DIR}/api/.env <<EOF
RESEND_API_KEY=${RESEND_API_KEY}
RESEND_AUDIENCE_ID=${RESEND_AUDIENCE_ID}
PORT=3000
EOF"
echo "✅ Environment file created"
echo ""

echo "📦 Step 5: Installing PM2..."
ssh ${DEPLOY_TARGET} "npm install -g pm2 || true"
echo "✅ PM2 installed"
echo ""

echo "🚀 Step 6: Starting API service..."
ssh ${DEPLOY_TARGET} "cd ${REMOTE_WEB_DIR}/api && pm2 delete waitlist-api || true && pm2 start waitlist.js --name waitlist-api && pm2 save"
echo "✅ API service started"
echo ""

echo "⚙️  Step 7: Configuring nginx..."
ssh ${DEPLOY_TARGET} "grep -q 'location /api/waitlist' /etc/nginx/sites-available/default || cat >> /etc/nginx/sites-available/default <<'NGINX'

  # Waitlist API
  location /api/waitlist {
    proxy_pass http://localhost:3000;
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_set_header Host \$host;
    proxy_cache_bypass \$http_upgrade;
  }
NGINX
"
echo "✅ Nginx configured"
echo ""

echo "🔄 Step 8: Reloading nginx..."
ssh ${DEPLOY_TARGET} "nginx -t && systemctl reload nginx"
echo "✅ Nginx reloaded"
echo ""

echo "📄 Step 9: Deploying updated landing page..."
scp "${SCRIPT_DIR}/../pictureFrame/software/landing_page/index.html" ${DEPLOY_TARGET}:${REMOTE_WEB_DIR}/index.html
echo "✅ Landing page updated"
echo ""

echo "🧪 Step 10: Testing API..."
sleep 2
RESPONSE=$(curl -s -X POST http://moveometer.com/api/waitlist \
  -H "Content-Type: application/json" \
  -d '{"email":"test@moveometer.com"}' | head -c 100)

if [[ $RESPONSE == *"success"* ]] || [[ $RESPONSE == *"already exists"* ]]; then
  echo "✅ API test successful"
else
  echo "⚠️  API test response: $RESPONSE"
fi
echo ""

echo "🎉 Deployment complete!"
echo ""
echo "API endpoint: http://moveometer.com/api/waitlist"
echo "Landing page: http://moveometer.com/"
echo ""
echo "Monitor logs: ssh ${DEPLOY_TARGET} 'pm2 logs waitlist-api'"
echo "Check status: ssh ${DEPLOY_TARGET} 'pm2 status'"
