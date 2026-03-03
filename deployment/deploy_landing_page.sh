#!/bin/bash
# Deploy landing page and move dashboard to /dashboard/ subdirectory

set -e  # Exit on error

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

echo "=== moveOmeter Landing Page Deployment ==="
echo "Server: ${SERVER_IP}"
echo "Remote dir: ${REMOTE_WEB_DIR}"
echo ""

# Step 1: Backup current dashboard
echo "📦 Step 1: Creating backup of current dashboard..."
ssh ${DEPLOY_TARGET} "cd ${REMOTE_WEB_DIR} && tar -czf ~/moveometer_dashboard_backup_\$(date +%Y%m%d_%H%M%S).tar.gz ."
echo "✅ Backup created in home directory"
echo ""

# Step 2: Create dashboard subdirectory
echo "📁 Step 2: Creating /dashboard/ subdirectory..."
ssh ${DEPLOY_TARGET} "mkdir -p ${REMOTE_WEB_DIR}/dashboard"
echo "✅ Directory created"
echo ""

# Step 3: Move current files to /dashboard/
echo "🚚 Step 3: Moving current dashboard to /dashboard/..."
ssh ${DEPLOY_TARGET} "cd ${REMOTE_WEB_DIR} && \
  find . -maxdepth 1 -type f -not -name '.*' -exec mv {} dashboard/ \; && \
  find . -maxdepth 1 -type d -not -name '.' -not -name '..' -not -name 'dashboard' -exec mv {} dashboard/ \;"
echo "✅ Dashboard files moved to /dashboard/"
echo ""

# Step 4: Copy landing page to web root
echo "📄 Step 4: Copying landing page to web root..."
LOCAL_LANDING_PAGE="${SCRIPT_DIR}/../pictureFrame/software/landing_page/index.html"
scp "${LOCAL_LANDING_PAGE}" ${DEPLOY_TARGET}:${REMOTE_WEB_DIR}/index.html
echo "✅ Landing page deployed"
echo ""

# Step 5: Set permissions
echo "🔒 Step 5: Setting permissions..."
ssh ${DEPLOY_TARGET} "chown -R www-data:www-data ${REMOTE_WEB_DIR} && \
  chmod -R 755 ${REMOTE_WEB_DIR}"
echo "✅ Permissions set"
echo ""

# Step 6: Check nginx config
echo "🔍 Step 6: Checking nginx configuration..."
ssh ${DEPLOY_TARGET} "nginx -t"
echo "✅ Nginx config is valid"
echo ""

# Step 7: Reload nginx
echo "🔄 Step 7: Reloading nginx..."
ssh ${DEPLOY_TARGET} "systemctl reload nginx"
echo "✅ Nginx reloaded"
echo ""

echo "🎉 Deployment complete!"
echo ""
echo "Landing page: http://moveometer.com/"
echo "Dashboard: http://moveometer.com/dashboard/"
echo ""
echo "Backup location: ~/moveometer_dashboard_backup_*.tar.gz"
