# moveOmeter Real-Time Dashboard

Beautiful web-based dashboard for visualizing mmWave sensor data in real-time.

## Features

- 📊 **Live Charts** - Heart rate, respiration, presence, and sleep quality
- 🔴 **Real-Time Updates** - Automatic updates via Supabase Realtime
- ⚠️ **Alerts** - Visual warnings for apnea events, struggles, and unusual activity
- 📱 **Responsive Design** - Works on desktop, tablet, and mobile
- 🎨 **Beautiful UI** - Modern gradient design with smooth animations

## Quick Start

### Option 1: Simple File Open (Easiest)

1. Open `index.html` directly in your web browser:
   ```bash
   open index.html
   ```
   Or just double-click `index.html` in Finder

2. The dashboard will connect to your Supabase database automatically

**Note:** Real-time updates might not work with `file://` protocol. Use Option 2 for full functionality.

### Option 2: Local Web Server (Recommended)

Using Python 3:
```bash
cd /Users/johnreine/Dropbox/john/2025_work/moveOmeter/web/dashboard
python3 -m http.server 8000
```

Then open: http://localhost:8000

### Option 3: Using Node.js

```bash
npx http-server -p 8000
```

Then open: http://localhost:8000

## Configuration

Edit `config.js` to customize:

```javascript
// Device to monitor (set to null to show all devices)
deviceId: 'ESP32C6_001',

// How often to refresh data (milliseconds)
refreshInterval: 5000,

// Number of data points to show in charts
maxDataPoints: 20
```

## Dashboard Sections

### Current Metrics (Top Cards)
- **Heart Rate** - Real-time heart rate in BPM
- **Respiration** - Breaths per minute
- **Presence** - Is person detected?
- **In Bed** - Current bed occupancy
- **Sleep Quality** - Overall sleep quality score (0-100)
- **Apnea Events** - Count of breathing pause events

### Charts
1. **Heart Rate** - Line chart showing heart rate over last 20 readings
2. **Respiration Rate** - Breathing pattern visualization
3. **Presence & Movement** - Dual-axis chart showing detection and movement intensity
4. **Sleep Quality** - Bar chart of sleep quality scores over time

### Alerts
Automatic alerts appear for:
- 🚨 Apnea events (breathing stopped)
- ⚠️ Abnormal struggle detected
- 🛏️ Out of bed during night hours (10pm-6am)
- 👤 Person left monitored area

## Real-Time Updates

The dashboard uses **Supabase Realtime** to automatically update when new data arrives from your ESP32-C6 device. No page refresh needed!

How it works:
1. ESP32-C6 inserts new row into Supabase table
2. Supabase broadcasts change via WebSocket
3. Dashboard receives update instantly
4. Charts and metrics update automatically

## Troubleshooting

### Dashboard shows "Disconnected"
- Check that Supabase URL and anon key are correct in `config.js`
- Verify the table name matches your database
- Check browser console (F12) for error messages

### No data appears
- Verify ESP32-C6 is running and uploading data
- Check Supabase table has data: `SELECT * FROM mmwave_sensor_data LIMIT 10;`
- Confirm `deviceId` in `config.js` matches your device

### Charts not updating
- Ensure you're using a web server (Option 2 or 3), not `file://`
- Check browser console for WebSocket connection errors
- Try refreshing the page

### Real-time not working
- Supabase Realtime requires Row Level Security to be properly configured
- Verify the table has RLS policies allowing reads
- Check your Supabase project has Realtime enabled

## Customization

### Change Color Scheme
Edit the CSS in `index.html`:
```css
background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
```

### Add More Charts
1. Add a new canvas element in `index.html`:
   ```html
   <canvas id="myNewChart"></canvas>
   ```

2. Initialize the chart in `dashboard.js`:
   ```javascript
   charts.myNew = new Chart(document.getElementById('myNewChart'), {
       // Chart configuration
   });
   ```

3. Update the chart in the `updateCharts()` function

### Modify Alert Conditions
Edit the `checkAlerts()` function in `dashboard.js` to add custom alert logic.

## Deployment

### Deploy to Static Hosting

**Netlify:**
```bash
# Install Netlify CLI
npm install -g netlify-cli

# Deploy
cd /Users/johnreine/Dropbox/john/2025_work/moveOmeter/web/dashboard
netlify deploy --prod
```

**Vercel:**
```bash
# Install Vercel CLI
npm install -g vercel

# Deploy
cd /Users/johnreine/Dropbox/john/2025_work/moveOmeter/web/dashboard
vercel --prod
```

**GitHub Pages:**
1. Create a GitHub repository
2. Push the `web/dashboard` folder
3. Enable GitHub Pages in repository settings

### Security Considerations

⚠️ **IMPORTANT:** The `config.js` file contains your Supabase anon key. This is safe for client-side use, but:

1. **Enable Row Level Security (RLS)** on your Supabase table
2. **Never use the service_role key** in client-side code
3. For production, consider using environment variables with a build step

## Performance Tips

- **Reduce `maxDataPoints`** if charts feel sluggish (try 10-15)
- **Increase `refreshInterval`** if you don't need sub-second updates
- **Use specific `deviceId`** to filter data for better performance

## Browser Support

Works on all modern browsers:
- ✅ Chrome/Edge (recommended)
- ✅ Firefox
- ✅ Safari
- ✅ Mobile browsers (iOS Safari, Chrome Mobile)

Requires JavaScript enabled.

## Next Steps

1. **Add authentication** - Require login to view dashboard
2. **Historical data view** - Add date picker to view past data
3. **Export functionality** - Download data as CSV/PDF
4. **Mobile app** - Convert to React Native or Flutter app
5. **Notifications** - Add push notifications for critical alerts

## Files

- `index.html` - Main dashboard page
- `dashboard.js` - Chart logic and data fetching
- `config.js` - Configuration (Supabase credentials)
- `README.md` - This file

## License

Part of the moveOmeter IoT elderly monitoring project.
