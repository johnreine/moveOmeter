# Waitlist API Setup

This API endpoint captures email addresses from the landing page and adds them to a Resend audience.

## Prerequisites

1. **Resend Account**: Sign up at https://resend.com
2. **API Key**: Get from https://resend.com/api-keys
3. **Audience**: Create an audience at https://resend.com/audiences

## Setup Instructions

### Option 1: Node.js Server (Recommended)

1. Install Node.js on the server:
```bash
ssh root@167.71.107.200
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs
```

2. Create API directory:
```bash
mkdir -p /var/www/moveometer/api
```

3. Copy the waitlist.js file to the server:
```bash
scp web/api/waitlist.js root@167.71.107.200:/var/www/moveometer/api/
```

4. Create environment file:
```bash
ssh root@167.71.107.200
cat > /var/www/moveometer/api/.env <<EOF
RESEND_API_KEY=your_api_key_here
RESEND_AUDIENCE_ID=your_audience_id_here
EOF
```

5. Install PM2 to run the API:
```bash
npm install -g pm2
cd /var/www/moveometer/api
pm2 start waitlist.js --name waitlist-api
pm2 save
pm2 startup
```

6. Configure nginx to proxy `/api/waitlist`:
```nginx
location /api/waitlist {
    proxy_pass http://localhost:3000;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_set_header Host $host;
    proxy_cache_bypass $http_upgrade;
}
```

7. Reload nginx:
```bash
nginx -t && systemctl reload nginx
```

### Option 2: Serverless Function (Alternative)

If you prefer serverless, you can deploy this as a Supabase Edge Function or Vercel Function.

## Testing

Test the endpoint:
```bash
curl -X POST http://moveometer.com/api/waitlist \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com"}'
```

Expected response:
```json
{"success":true,"message":"Added to waitlist"}
```

## Monitoring

View logs:
```bash
pm2 logs waitlist-api
```

Check status:
```bash
pm2 status
```

## Environment Variables

- `RESEND_API_KEY`: Your Resend API key
- `RESEND_AUDIENCE_ID`: The audience ID to add contacts to
- `PORT`: Port to listen on (default: 3000)
