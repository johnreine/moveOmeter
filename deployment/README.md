# moveOmeter Dashboard Deployment Guide

This guide will help you deploy the moveOmeter dashboard to a Digital Ocean droplet.

## Prerequisites

- Digital Ocean droplet running Ubuntu 22.04 LTS (or similar)
- Root SSH access to the droplet
- Domain name (optional, for SSL)

## Deployment Steps

### 1. Initial Server Setup

SSH into your droplet as root:
```bash
ssh root@your-droplet-ip
```

### 2. Create Non-Root User

```bash
# Create deploy user
adduser deploy
usermod -aG sudo deploy

# Switch to deploy user
su - deploy
cd ~
```

### 3. Install Claude Code (Optional)

If you want to use Claude Code to help with setup:

```bash
# Install Claude Code
curl -fsSL https://claude.ai/install.sh | sh

# Add to PATH (if needed)
export PATH="$HOME/.local/bin:$PATH"
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc

# Verify installation
which claude
claude --version

# Run Claude Code
claude
```

**Troubleshooting Claude Code:**
- If `claude` command not found, try: `~/.local/bin/claude`
- Check if installed: `ls -la ~/.local/bin/claude`
- If installation failed, try manual install from: https://github.com/anthropics/claude-code

### 4. Manual Setup Instructions (Without Claude)

If you prefer to set up manually or Claude Code isn't available:

#### A. Install Nginx
```bash
sudo apt update
sudo apt install -y nginx
```

#### B. Upload Dashboard Files

From your local machine, upload the dashboard files:
```bash
# From your local machine (in the deployment directory)
scp -r dashboard/* deploy@your-droplet-ip:/tmp/dashboard/
```

Then on the droplet:
```bash
sudo mkdir -p /var/www/moveometer
sudo cp -r /tmp/dashboard/* /var/www/moveometer/
sudo chown -R www-data:www-data /var/www/moveometer
sudo chmod -R 755 /var/www/moveometer
```

#### C. Configure Nginx

Create Nginx site configuration:
```bash
sudo nano /etc/nginx/sites-available/moveometer
```

Paste this configuration:
```nginx
server {
    listen 80;
    listen [::]:80;
    server_name your-domain.com;  # Change this to your domain or IP

    root /var/www/moveometer;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }

    # Enable gzip compression
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript application/json application/javascript application/xml+rss;

    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
```

Enable the site:
```bash
sudo ln -s /etc/nginx/sites-available/moveometer /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

#### D. Configure Firewall
```bash
sudo ufw allow 'Nginx Full'
sudo ufw allow OpenSSH
sudo ufw enable
```

#### E. Optional: Set Up SSL with Let's Encrypt

```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d your-domain.com
```

### 5. If Using Claude Code

Instead of manual setup, you can ask Claude to do everything:

```
Please set up an Nginx web server to host a static dashboard:

1. Install Nginx
2. Create /var/www/moveometer directory
3. Copy files from ~/dashboard to /var/www/moveometer
4. Set proper permissions (www-data owner)
5. Create Nginx configuration to serve the site on port 80
6. Configure firewall (UFW) to allow HTTP/HTTPS
7. Enable and start Nginx
8. If I provide a domain name, set up SSL with Let's Encrypt

The dashboard is a static site with index.html, dashboard.js, and config.js.
It needs to be accessible via browser and serve the files with proper MIME types.
```

## Configuration

Before deployment, update `config.js` with your Supabase credentials:
- Open `dashboard/config.js`
- Verify `SUPABASE_URL` and `SUPABASE_ANON_KEY` are correct
- These should already be set from your local development

## Verify Deployment

1. Open your browser and navigate to `http://your-droplet-ip` or `http://your-domain.com`
2. You should see the moveOmeter dashboard
3. Check browser console for any errors
4. Verify data is loading from Supabase

## Updating the Dashboard

To update the dashboard files:

```bash
# From local machine
scp -r dashboard/* deploy@your-droplet-ip:/tmp/dashboard/

# On droplet
sudo cp -r /tmp/dashboard/* /var/www/moveometer/
sudo chown -R www-data:www-data /var/www/moveometer
sudo systemctl reload nginx
```

Or create a deployment script (see `deploy.sh` if included).

## Troubleshooting

**Nginx won't start:**
```bash
sudo nginx -t  # Check configuration syntax
sudo systemctl status nginx
sudo journalctl -xeu nginx
```

**Can't access the site:**
- Check firewall: `sudo ufw status`
- Check Nginx is running: `sudo systemctl status nginx`
- Check DNS if using domain name

**Dashboard loads but no data:**
- Check browser console for errors
- Verify Supabase credentials in config.js
- Check Supabase RLS policies allow anonymous access

**Permission errors:**
```bash
sudo chown -R www-data:www-data /var/www/moveometer
sudo chmod -R 755 /var/www/moveometer
```

## Security Notes

- The dashboard connects directly to Supabase from the browser
- Supabase credentials are client-side (anon key is safe to expose)
- For production, consider:
  - Setting up SSL/HTTPS (required for production)
  - Configuring stricter Supabase RLS policies
  - Adding rate limiting
  - Setting up monitoring/alerts

## Files Included

- `dashboard/index.html` - Main dashboard page
- `dashboard/dashboard.js` - Dashboard JavaScript logic
- `dashboard/config.js` - Supabase configuration (includes credentials)

## Support

If you encounter issues:
1. Check the troubleshooting section above
2. Review Nginx error logs: `sudo tail -f /var/log/nginx/error.log`
3. Check browser console for JavaScript errors
4. Verify Supabase connection and RLS policies
