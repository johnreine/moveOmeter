/*
 * Configuration file for mmWave Supabase Data Collector
 *
 * IMPORTANT: Do NOT commit this file to public repositories!
 * Add config.h to your .gitignore
 */

#ifndef CONFIG_H
#define CONFIG_H

// WiFi Configuration
#define WIFI_SSID "Pleasevote"
#define WIFI_PASSWORD "peaceonearth"

// Supabase Configuration
// Get these from: Supabase Dashboard -> Settings -> API
#define SUPABASE_URL "https://nrisopysitetqycvwxsq.supabase.co"
#define SUPABASE_ANON_KEY "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5yaXNvcHlzaXRldHF5Y3Z3eHNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk5ODI1NzQsImV4cCI6MjA4NTU1ODU3NH0.FEIYoWTnVVGnYtCyO0j3SIzabgJQLZxR6xr0hrrj-PM"

// Database Configuration
#define SUPABASE_TABLE "mmwave_sensor_data"  // Your table name

// Device Configuration
#define DEVICE_ID "ESP32C6_001"  // Unique identifier for this device
#define LOCATION "bedroom_1"     // Device location (optional)

// Data Collection Settings
#define DATA_INTERVAL 5000       // Milliseconds between data collections
#define RETRY_ATTEMPTS 3         // Number of retry attempts for failed uploads
#define RETRY_DELAY 2000         // Delay between retry attempts (ms)

#endif
