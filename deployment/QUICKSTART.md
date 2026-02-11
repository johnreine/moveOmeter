# Quick Start Guide

## Option 1: Automated Deployment (Recommended)

From your local machine (in this deployment directory):

```bash
# Make sure you have SSH access to your droplet
./deploy.sh deploy@your-droplet-ip

# Example:
./deploy.sh deploy@165.232.123.45
```

This will:
- Upload all dashboard files
- Install them in `/var/www/moveometer`
- Set proper permissions
- Reload Nginx (if installed)

**Note:** Nginx must already be installed on the server. See README.md for setup.

## Option 2: Use Claude Code on Droplet

1. SSH into your droplet:
   ```bash
   ssh root@your-droplet-ip
   ```

2. Create non-root user:
   ```bash
   adduser deploy
   usermod -aG sudo deploy
   su - deploy
   ```

3. Upload deployment files:
   ```bash
   # From your local machine (in deployment directory)
   scp -r . deploy@your-droplet-ip:~/moveometer-deploy/
   ```

4. On the droplet, install Claude Code:
   ```bash
   cd ~/moveometer-deploy

   # Install Claude Code
   curl -fsSL https://claude.ai/install.sh | sh

   # Add to PATH
   export PATH="$HOME/.local/bin:$PATH"

   # Run Claude
   claude
   ```

5. Ask Claude to set up the server:
   ```
   I have a static web dashboard in the ~/moveometer-deploy/dashboard directory.
   Please help me:
   1. Install and configure Nginx
   2. Set up the dashboard to be served at /var/www/moveometer
   3. Configure proper permissions
   4. Set up firewall rules
   5. Test that it's working

   The dashboard is static HTML/JS that connects to Supabase.
   ```

## Option 3: Manual Setup

See README.md for complete manual setup instructions.

## After Deployment

Visit your dashboard at:
- `http://your-droplet-ip` (if no domain)
- `http://your-domain.com` (if you have a domain)

## Troubleshooting Claude Code Installation

If you get "command not found" error:

```bash
# Check if installed
ls -la ~/.local/bin/claude

# If it exists, add to PATH
export PATH="$HOME/.local/bin:$PATH"
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc

# Try running directly
~/.local/bin/claude

# If still not working, try manual installation:
mkdir -p ~/.local/bin
# Download from https://github.com/anthropics/claude-code/releases
```

Alternative: Just set up manually following README.md instructions!
