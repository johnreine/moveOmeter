// Waitlist API endpoint using Resend
// This handles email submissions from the landing page

const https = require('https');

// Resend API configuration
const RESEND_API_KEY = process.env.RESEND_API_KEY || 'YOUR_RESEND_API_KEY';
const AUDIENCE_ID = process.env.RESEND_AUDIENCE_ID || 'YOUR_AUDIENCE_ID';

/**
 * Add email to Resend waitlist
 */
function addToWaitlist(email, callback) {
  const data = JSON.stringify({
    email: email,
    unsubscribed: false,
    // Optional: add custom fields
    // first_name: '',
    // source: 'landing_page'
  });

  const options = {
    hostname: 'api.resend.com',
    port: 443,
    path: `/audiences/${AUDIENCE_ID}/contacts`,
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${RESEND_API_KEY}`,
      'Content-Type': 'application/json',
      'Content-Length': data.length
    }
  };

  const req = https.request(options, (res) => {
    let body = '';

    res.on('data', (chunk) => {
      body += chunk;
    });

    res.on('end', () => {
      if (res.statusCode === 200 || res.statusCode === 201) {
        callback(null, { success: true, message: 'Added to waitlist' });
      } else {
        callback(new Error(`Resend API error: ${res.statusCode} ${body}`), null);
      }
    });
  });

  req.on('error', (error) => {
    callback(error, null);
  });

  req.write(data);
  req.end();
}

/**
 * HTTP handler for waitlist submissions
 */
function handleRequest(req, res) {
  // Set CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  // Handle preflight
  if (req.method === 'OPTIONS') {
    res.writeHead(200);
    res.end();
    return;
  }

  // Only allow POST
  if (req.method !== 'POST') {
    res.writeHead(405, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Method not allowed' }));
    return;
  }

  // Parse request body
  let body = '';
  req.on('data', chunk => {
    body += chunk.toString();
  });

  req.on('end', () => {
    try {
      const { email } = JSON.parse(body);

      // Validate email
      if (!email || !email.match(/^[^\s@]+@[^\s@]+\.[^\s@]+$/)) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Invalid email address' }));
        return;
      }

      // Add to Resend waitlist
      addToWaitlist(email, (error, result) => {
        if (error) {
          console.error('Resend error:', error);
          res.writeHead(500, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ error: 'Failed to add to waitlist' }));
        } else {
          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify(result));
        }
      });
    } catch (error) {
      res.writeHead(400, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'Invalid request body' }));
    }
  });
}

module.exports = handleRequest;

// For standalone server (development)
if (require.main === module) {
  const http = require('http');
  const PORT = process.env.PORT || 3000;

  const server = http.createServer(handleRequest);
  server.listen(PORT, () => {
    console.log(`Waitlist API listening on port ${PORT}`);
  });
}
