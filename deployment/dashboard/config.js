// Supabase Configuration
// IMPORTANT: In production, use environment variables or a backend proxy
// Do NOT commit sensitive keys to public repositories

const SUPABASE_CONFIG = {
    url: 'https://nrisopysitetqycvwxsq.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5yaXNvcHlzaXRldHF5Y3Z3eHNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk5ODI1NzQsImV4cCI6MjA4NTU1ODU3NH0.FEIYoWTnVVGnYtCyO0j3SIzabgJQLZxR6xr0hrrj-PM',
    table: 'mmwave_sensor_data'
};

// Dashboard Configuration
const DASHBOARD_CONFIG = {
    refreshInterval: 3000,      // Fetch new data every 3 seconds
    maxDataPoints: 100,         // Number of data points to show in charts
    deviceId: 'ESP32C6_001',    // Filter data for specific device (set to null for all devices)
};
