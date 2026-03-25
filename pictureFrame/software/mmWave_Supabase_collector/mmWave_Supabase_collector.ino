/*
 * mmWave Supabase Data Collector for ESP32-C6
 *
 * Collects comprehensive data from DF Robot SEN0623 (C1001 mmWave sensor)
 * and uploads it to Supabase using ESPSupabase library
 *
 * Hardware connections (ESP32-C6 Feather):
 * - mmWave TX -> ESP32-C6 RX (GPIO17)
 * - mmWave RX -> ESP32-C6 TX (GPIO16)
 * - mmWave GND -> ESP32-C6 GND
 * - mmWave VCC -> ESP32-C6 5V
 *
 * Required Libraries (install via Arduino Library Manager):
 * - DFRobot_HumanDetection
 * - ESPSupabase
 * - HTTPUpdate (built-in)
 * - Adafruit_DPS310
 */

#include <WiFi.h>
#include <ESPSupabase.h>
#include <HTTPClient.h>
#include <HTTPUpdate.h>
#include <WiFiClientSecure.h>
#include <time.h>
#include <Adafruit_NeoPixel.h>
#include <Adafruit_DPS310.h>
#include "DFRobot_HumanDetection.h"
#include "config.h"
#include "ble_provisioning.h"

// Firmware version (update this with each release)
#define FIRMWARE_VERSION "1.0.0"
#define DEVICE_MODEL "ESP32C6_MOVEOMETER"

// Debug mode - set to false for production to disable serial output
#define DEBUG_MODE true  // Set to false to disable all debug serial output

// Debug print functions - only print if DEBUG_MODE is true AND serial is connected
template<typename T>
void debugPrint(T message) {
  #if DEBUG_MODE
    if (Serial) {
      Serial.print(message);
    }
  #endif
}

// Overload for float with precision
void debugPrint(float value, int precision) {
  #if DEBUG_MODE
    if (Serial) {
      Serial.print(value, precision);
    }
  #endif
}

void debugPrint(double value, int precision) {
  #if DEBUG_MODE
    if (Serial) {
      Serial.print(value, precision);
    }
  #endif
}

template<typename T>
void debugPrintln(T message) {
  #if DEBUG_MODE
    if (Serial) {
      Serial.println(message);
    }
  #endif
}

// Overload for empty println
void debugPrintln() {
  #if DEBUG_MODE
    if (Serial) {
      Serial.println();
    }
  #endif
}

// Overload for time printing (struct tm)
void debugPrintln(struct tm* timeinfo, const char* format) {
  #if DEBUG_MODE
    if (Serial) {
      Serial.println(timeinfo, format);
    }
  #endif
}

// For printf-style formatting
void debugPrintf(const char* format, ...) {
  #if DEBUG_MODE
    if (Serial) {
      char buffer[256];
      va_list args;
      va_start(args, format);
      vsnprintf(buffer, sizeof(buffer), format, args);
      va_end(args);
      Serial.print(buffer);
    }
  #endif
}

// For serial write (used in command echo)
void debugWrite(char c) {
  #if DEBUG_MODE
    if (Serial) {
      Serial.write(c);
    }
  #endif
}

// For serial flush
void debugFlush() {
  #if DEBUG_MODE
    if (Serial) {
      Serial.flush();
    }
  #endif
}

// NeoPixel configuration
#define NEOPIXEL_PIN 8         // GPIO8 for NeoPixel data (ESP32-C6 Feather onboard)
#define NEOPIXEL_COUNT 1       // Number of NeoPixels
#define NEOPIXEL_BRIGHTNESS 128 // Max brightness (0-255)

// NTP Time Configuration
// Always store in UTC - web UI will handle local display
#define NTP_SERVER1 "pool.ntp.org"
#define NTP_SERVER2 "time.nist.gov"
#define NTP_SERVER3 "time.google.com"
#define GMT_OFFSET_SEC 0      // UTC (no offset)
#define DAYLIGHT_OFFSET_SEC 0  // UTC (no DST)

// Time sync interval (5 minutes)
#define TIME_SYNC_INTERVAL 300000
unsigned long lastTimeSyncMillis = 0;

// WiFi reconnection intervals - tiered backoff strategy
#define WIFI_RECONNECT_INTERVAL_INITIAL 10000   // First 5 minutes: retry every 10 seconds
#define WIFI_RECONNECT_INTERVAL_MEDIUM 20000    // 5-10 minutes: retry every 20 seconds
#define WIFI_RECONNECT_INTERVAL_LONG 30000      // After 10 minutes: retry every 30 seconds

unsigned long lastWiFiReconnectAttempt = 0;
unsigned long wifiDisconnectedSince = 0;  // Track when WiFi was first lost

// Serial port definitions
#define USB_SERIAL Serial
#define MMWAVE_SERIAL Serial1

// UART pins for ESP32-C6 Feather
#define MMWAVE_RX_PIN 17  // ESP32-C6 RX (connect to mmWave TX)
#define MMWAVE_TX_PIN 16  // ESP32-C6 TX (connect to mmWave RX)

// Sensor power control (optional - requires MOSFET circuit)
#define SENSOR_POWER_PIN 5  // GPIO5 controls MOSFET gate
#define ENABLE_POWER_CONTROL false  // Set to true when MOSFET circuit is installed

// Create sensor, database, and NeoPixel objects
DFRobot_HumanDetection sensor(&MMWAVE_SERIAL);
Supabase db;
Adafruit_NeoPixel pixel(NEOPIXEL_COUNT, NEOPIXEL_PIN, NEO_GRB + NEO_KHZ800);
Adafruit_DPS310 dps;

// Pressure monitoring variables
bool dpsInitialized = false;  // Track if DPS310 initialized successfully
float currentPressure = 0.0;  // Current pressure in hPa
float currentTemperature = 0.0; // Current temperature in C
float lastPressure = 0.0;     // Previous reading for event detection
int doorEventsCount = 0;      // Door events detected since last upload
unsigned long lastPressureReadTime = 0;
unsigned long lastPressureUploadTime = 0; // Track when we last sent pressure/temp
#define PRESSURE_SAMPLE_INTERVAL 100  // Sample every 100ms (10 Hz) for event detection
#define PRESSURE_UPLOAD_INTERVAL 600000 // Send pressure/temp every 10 minutes
#define DOOR_EVENT_THRESHOLD 0.3      // Pressure change in hPa to detect door event

// Error states for NeoPixel indication
enum ErrorState {
  ERROR_NONE = 0,           // No error - normal operation
  ERROR_UPLOAD_FAILED,      // Data upload failed (orange)
  ERROR_WIFI_DISCONNECTED,  // WiFi disconnected (red blinking)
  ERROR_SENSOR_FAILED       // Sensor communication failed (purple)
};

ErrorState currentError = ERROR_NONE;
unsigned long lastErrorBlinkTime = 0;
bool errorBlinkState = false;

// Device configuration (fetched from database)
struct DeviceConfig {
  String operationalMode = "fall_detection";  // "fall_detection" or "sleep"
  String dataCollectionMode = "quick";  // "quick" or "medium"
  int fallDetectionIntervalMs = 20000;  // Sampling rate for fall detection mode
  int sleepModeIntervalMs = 20000;      // Sampling rate for sleep mode
  int configCheckIntervalMs = 20000;    // How often to check for config updates
  int otaCheckIntervalMs = 3600000;     // How often to check for firmware updates
  int sensorQueryDelayMs = 0;           // Delay between individual sensor queries
  int queryRetryAttempts = 1;           // Number of retry attempts for failed queries
  int queryRetryDelayMs = 100;          // Delay between retry attempts
  bool enableSupplementalQueries = true; // Enable/disable supplemental data collection
  String supplementalCycleMode = "rotating"; // "rotating", "all", or "none"
  int installHeightCm = 125;
  int fallSensitivity = 3;             // Valid range: 0-3 (3 = most sensitive)
  int installAngle = 0;
  bool positionTrackingEnabled = true;
  int seatedDistanceThresholdCm = 100;  // Seated horizontal distance threshold
  int motionDistanceThresholdCm = 150;  // Motion horizontal distance threshold
  int fallTimeSec = 5;                 // Delay before reporting fall (prevents false triggers)
  int residenceTimeSec = 30;           // Seconds motionless before "lying on floor" alert
  bool residenceSwitch = true;         // Enable static residency (lying on floor) detection
} deviceConfig;

unsigned long lastQuickDataTime = 0;
unsigned long lastConfigFetchTime = 0;
unsigned long lastConfigCheckTime = 0;
unsigned long lastOtaCheckTime = 0;
unsigned long lastKeepAliveTime = 0;
unsigned long startTime = 0;
int uploadFailCount = 0;
int supplementalQueryIndex = 0;  // Cycles through additional queries

// Keep-alive interval when no presence detected (30 seconds)
#define KEEP_ALIVE_INTERVAL 30000

// Legacy backup intervals (used only if database values fail to load)
#define CONFIG_FETCH_INTERVAL 600000   // 10 minutes - periodic backup config sync

// Helper function to get current interval based on mode
int getDataInterval() {
  return (deviceConfig.operationalMode == "sleep") ?
         deviceConfig.sleepModeIntervalMs :
         deviceConfig.fallDetectionIntervalMs;
}

// Function to reset mmWave sensor (requires MOSFET circuit)
void resetSensor() {
  if (!ENABLE_POWER_CONTROL) {
    debugPrintln("ERROR: Power control not enabled!");
    return;
  }

  debugPrintln("\n*** Resetting mmWave sensor ***");

  // Power off sensor
  digitalWrite(SENSOR_POWER_PIN, LOW);
  debugPrintln("Sensor power: OFF");
  delay(3000);  // Wait 3 seconds

  // Power on sensor
  digitalWrite(SENSOR_POWER_PIN, HIGH);
  debugPrintln("Sensor power: ON");
  debugPrintln("Waiting for sensor initialization (10 seconds)...");
  delay(10000);  // Wait 10 seconds for sensor init

  // Reconfigure sensor
  debugPrint("Reconfiguring Fall Detection Mode... ");
  if (sensor.configWorkMode(DFRobot_HumanDetection::eFallingMode) != 0) {
    debugPrintln("FAILED!");
  } else {
    debugPrintln("SUCCESS!");
  }

  // Restore installation height
  sensor.dmInstallHeight(125);
  debugPrintln("Installation height restored to 125");

  debugPrintln("*** Sensor reset complete! ***\n");
}

// ========================================
// OTA Firmware Update Functions
// ========================================

// Update OTA status in database
void updateOtaStatus(String status, String error = "") {
  String json = "{";
  json += "\"ota_status\":\"" + status + "\",";
  json += "\"last_ota_check\":\"" + getISOTimestamp() + "\"";
  if (error.length() > 0) {
    json += ",\"ota_error\":\"" + error + "\"";
  }
  if (status == "success") {
    json += ",\"last_ota_update\":\"" + getISOTimestamp() + "\",";
    json += "\"firmware_version\":\"" + String(FIRMWARE_VERSION) + "\"";
  }
  json += "}";

  int statusCode = db.update(SUPABASE_TABLE).eq("device_id", DEVICE_ID).doUpdate(json);

  if (statusCode == 200 || statusCode == 204) {
    debugPrintln("OTA status updated: " + status);
  }
}

// Compare version strings (returns 1 if v1 > v2, -1 if v1 < v2, 0 if equal)
int compareVersions(String v1, String v2) {
  int v1Major = 0, v1Minor = 0, v1Patch = 0;
  int v2Major = 0, v2Minor = 0, v2Patch = 0;

  sscanf(v1.c_str(), "%d.%d.%d", &v1Major, &v1Minor, &v1Patch);
  sscanf(v2.c_str(), "%d.%d.%d", &v2Major, &v2Minor, &v2Patch);

  if (v1Major != v2Major) return (v1Major > v2Major) ? 1 : -1;
  if (v1Minor != v2Minor) return (v1Minor > v2Minor) ? 1 : -1;
  if (v1Patch != v2Patch) return (v1Patch > v2Patch) ? 1 : -1;
  return 0;
}

// Check for firmware updates
void checkForFirmwareUpdate() {
  debugPrintln("\n[OTA] Checking for firmware updates...");
  debugPrintln("Current version: " + String(FIRMWARE_VERSION));

  updateOtaStatus("checking");

  // Query latest firmware version
  String query = "version,download_url,md5_checksum,mandatory,release_notes";
  String response = db.select(query).from("firmware_updates")
    .eq("device_model", DEVICE_MODEL)
    .order("created_at", "desc", false)
    .limit(1)
    .doSelect();

  if (response.length() == 0) {
    debugPrintln("[OTA] Failed to query firmware updates");
    updateOtaStatus("failed", "Query failed");
    return;
  }
  debugPrintln("[OTA] Response: " + response);

  // Parse JSON response
  if (response.indexOf("\"version\":") < 0) {
    debugPrintln("[OTA] No firmware updates available");
    updateOtaStatus("idle");
    return;
  }

  // Extract version
  int versionStart = response.indexOf("\"version\":\"") + 11;
  int versionEnd = response.indexOf("\"", versionStart);
  String latestVersion = response.substring(versionStart, versionEnd);

  debugPrintln("[OTA] Latest version: " + latestVersion);

  // Compare versions
  int comparison = compareVersions(latestVersion, FIRMWARE_VERSION);

  if (comparison <= 0) {
    debugPrintln("[OTA] Already on latest version");
    updateOtaStatus("idle");
    return;
  }

  // Extract download URL
  int urlStart = response.indexOf("\"download_url\":\"") + 16;
  int urlEnd = response.indexOf("\"", urlStart);
  String downloadUrl = response.substring(urlStart, urlEnd);

  if (downloadUrl == "placeholder" || downloadUrl.length() < 10) {
    debugPrintln("[OTA] Invalid download URL");
    updateOtaStatus("failed", "Invalid download URL");
    return;
  }

  // Extract MD5 checksum if available
  String md5Checksum = "";
  int md5Start = response.indexOf("\"md5_checksum\":\"");
  if (md5Start > 0) {
    md5Start += 16;
    int md5End = response.indexOf("\"", md5Start);
    md5Checksum = response.substring(md5Start, md5End);
  }

  debugPrintln("[OTA] New version available: " + latestVersion);
  debugPrintln("[OTA] Download URL: " + downloadUrl);

  // Perform update
  performOtaUpdate(downloadUrl, md5Checksum);
}

// Perform OTA update
void performOtaUpdate(String url, String md5) {
  debugPrintln("\n[OTA] Starting firmware update...");
  debugPrintln("[OTA] URL: " + url);

  updateOtaStatus("downloading");

  WiFiClientSecure client;
  client.setInsecure();  // Acceptable for Supabase - data is still encrypted via TLS

  // Configure HTTP update
  httpUpdate.setLedPin(LED_BUILTIN, LOW);
  httpUpdate.rebootOnUpdate(false);  // We'll reboot manually after updating status

  // Set MD5 checksum if provided
  if (md5.length() == 32) {
    httpUpdate.setMD5sum(md5.c_str());
    debugPrintln("[OTA] Using MD5: " + md5);
  }

  // Perform update
  debugPrintln("[OTA] Downloading and flashing firmware...");
  updateOtaStatus("updating");

  t_httpUpdate_return ret = httpUpdate.update(client, url);

  switch(ret) {
    case HTTP_UPDATE_FAILED:
      debugPrintf("[OTA] Update failed. Error (%d): %s\n",
        httpUpdate.getLastError(), httpUpdate.getLastErrorString().c_str());
      updateOtaStatus("failed", httpUpdate.getLastErrorString());
      break;

    case HTTP_UPDATE_NO_UPDATES:
      debugPrintln("[OTA] No update needed");
      updateOtaStatus("idle");
      break;

    case HTTP_UPDATE_OK:
      debugPrintln("[OTA] Update successful!");
      updateOtaStatus("success");
      delay(2000);
      debugPrintln("[OTA] Rebooting...");
      ESP.restart();
      break;
  }
}

// Direct Supabase insert using HTTPClient (replaces buggy ESPSupabase library)
int supabaseInsert(String table, String json) {
  WiFiClientSecure client;
  client.setInsecure(); // Skip certificate validation

  HTTPClient http;
  String url = String(SUPABASE_URL) + "/rest/v1/" + table;

  http.begin(client, url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("apikey", SUPABASE_ANON_KEY);
  http.addHeader("Authorization", "Bearer " + String(SUPABASE_ANON_KEY));
  http.addHeader("Prefer", "return=minimal");

  int httpCode = http.POST(json);
  http.end();

  return httpCode;
}

// Direct Supabase select using HTTPClient (replaces buggy ESPSupabase library)
String supabaseSelect(String table, String column, String value) {
  WiFiClientSecure client;
  client.setInsecure();

  HTTPClient http;
  String url = String(SUPABASE_URL) + "/rest/v1/" + table + "?device_id=eq." + value + "&select=*";

  http.begin(client, url);
  http.addHeader("apikey", SUPABASE_ANON_KEY);
  http.addHeader("Authorization", "Bearer " + String(SUPABASE_ANON_KEY));

  int httpCode = http.GET();
  String response = "";

  if (httpCode == 200) {
    response = http.getString();
  }

  http.end();
  return response;
}

// Test raw HTTP insert to diagnose 401 errors
void testRawHTTPInsert() {
  debugPrintln("\n=== Testing Raw HTTP Insert ===");

  WiFiClientSecure client;
  client.setInsecure(); // Skip certificate validation for testing

  HTTPClient http;
  String url = String(SUPABASE_URL) + "/rest/v1/" + String(SUPABASE_TABLE);

  debugPrintln("URL: " + url);

  http.begin(client, url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("apikey", SUPABASE_ANON_KEY);
  http.addHeader("Authorization", "Bearer " + String(SUPABASE_ANON_KEY));
  http.addHeader("Prefer", "return=minimal");

  String json = "{\"device_id\":\"ESP32C6_001\",\"sensor_mode\":\"fall_detection\",\"body_movement\":99}";
  debugPrintln("JSON: " + json);

  int httpCode = http.POST(json);

  debugPrint("Raw HTTP Test - Status Code: ");
  debugPrintln(httpCode);
  debugPrint("Response: ");
  debugPrintln(http.getString());

  http.end();
  debugPrintln("=== Test Complete ===\n");
}

void setup() {
  // Initialize USB Serial for debugging
  USB_SERIAL.begin(115200);
  delay(2000);

  debugPrintln("\n=================================");
  debugPrintln("mmWave Supabase Data Collector");
  debugPrintln("=================================");

  // Initialize sensor power control pin (if enabled)
  if (ENABLE_POWER_CONTROL) {
    pinMode(SENSOR_POWER_PIN, OUTPUT);
    digitalWrite(SENSOR_POWER_PIN, HIGH);  // Sensor ON
    debugPrintln("Sensor power control: ENABLED");
  } else {
    debugPrintln("Sensor power control: DISABLED (direct power)");
  }

  // Initialize NeoPixel
  debugPrintln("Initializing NeoPixel...");
  pixel.begin();
  pixel.setBrightness(NEOPIXEL_BRIGHTNESS);
  pixel.clear();
  pixel.show();
  debugPrintln("NeoPixel initialized (off)");

  // Initialize DPS310 pressure sensor
  debugPrint("Initializing DPS310 pressure sensor... ");
  if (dps.begin_I2C(0x77)) {
    debugPrintln("SUCCESS!");
    dps.configurePressure(DPS310_64HZ, DPS310_64SAMPLES);  // High precision
    dps.configureTemperature(DPS310_64HZ, DPS310_64SAMPLES);

    // Take initial reading
    sensors_event_t temp_event, pressure_event;
    dps.getEvents(&temp_event, &pressure_event);
    currentPressure = pressure_event.pressure;
    lastPressure = currentPressure;
    debugPrint("Initial pressure: ");
    debugPrint(currentPressure);
    debugPrintln(" hPa");

    dpsInitialized = true;  // Sensor is working
  } else {
    debugPrintln("FAILED! (continuing without pressure sensor)");
    dpsInitialized = false;  // Sensor not available
  }

  // Check if we have WiFi credentials
  WiFiCredentials creds;
  bool hasWiFiConfig = loadWiFiCredentials(creds);

  if (!hasWiFiConfig && String(WIFI_SSID) == "YOUR_WIFI_SSID") {
    // No stored credentials and config.h has placeholder values
    // Enter BLE provisioning mode
    debugPrintln("\n╔═══════════════════════════════════════╗");
    debugPrintln("║  NO WIFI CONFIGURED                   ║");
    debugPrintln("║  Starting BLE Provisioning Mode...    ║");
    debugPrintln("╚═══════════════════════════════════════╝\n");

    // Flash NeoPixel blue to indicate BLE mode
    pixel.setPixelColor(0, pixel.Color(0, 0, 255));
    pixel.setBrightness(50);
    pixel.show();

    initBLEProvisioning();
    startBLEProvisioning();

    // Loop in BLE mode until credentials are received
    while (!credentialsReceived) {
      // Process any pending credentials from BLE write
      processPendingCredentials();

      // Blink LED to show we're in BLE mode
      delay(100);  // Shorter delay for faster processing
      static unsigned long lastBlink = 0;
      static bool ledState = false;
      if (millis() - lastBlink >= 1000) {
        lastBlink = millis();
        ledState = !ledState;
        pixel.setBrightness(ledState ? 50 : 10);
        pixel.show();
      }
    }
    // If we exit loop, credentials were received and device will reboot
  }

  // Connect to WiFi
  connectWiFi();

  // Initialize NTP time sync
  debugPrint("Syncing time with NTP servers... ");
  configTime(GMT_OFFSET_SEC, DAYLIGHT_OFFSET_SEC, NTP_SERVER1, NTP_SERVER2, NTP_SERVER3);

  // Wait for time to be set
  struct tm timeinfo;
  int attempts = 0;
  while (!getLocalTime(&timeinfo) && attempts < 10) {
    delay(500);
    debugPrint(".");
    attempts++;
  }

  if (getLocalTime(&timeinfo)) {
    debugPrintln(" SUCCESS!");
    debugPrint("Current time: ");
    debugPrintln(&timeinfo, "%Y-%m-%d %H:%M:%S");
  } else {
    debugPrintln(" FAILED! (will retry)");
  }

  // Test raw HTTP insert (for debugging 401 errors)
  testRawHTTPInsert();

  // Initialize Supabase
  debugPrint("Initializing Supabase... ");
  db.begin(SUPABASE_URL, SUPABASE_ANON_KEY);
  debugPrintln("SUCCESS!");

  // Initialize UART Serial for mmWave sensor
  MMWAVE_SERIAL.begin(115200, SERIAL_8N1, MMWAVE_RX_PIN, MMWAVE_TX_PIN);

  // Initialize sensor
  debugPrint("Initializing sensor (this takes ~10 seconds)... ");
  if (sensor.begin() != 0) {
    debugPrintln("FAILED!");
    debugPrintln("Please check wiring and power supply.");
    while(1) delay(1000);
  }
  debugPrintln("SUCCESS!");

  // Configure sensor to Fall Detection Mode
  debugPrint("Configuring Fall Detection Mode... ");
  if (sensor.configWorkMode(DFRobot_HumanDetection::eFallingMode) != 0) {
    debugPrintln("FAILED!");
    while(1) delay(1000);
  }
  debugPrintln("SUCCESS!");

  // Turn off LEDs for stealth operation
  sensor.configLEDLight(DFRobot_HumanDetection::eFALLLed, 0);

  // Set installation height (adjust based on your actual mounting height)
  sensor.dmInstallHeight(125);  // 250 cm = 8.2 feet
  debugPrint("Setting installation height to 125 cm... ");
  delay(1000);
  debugPrintln("DONE!");

  debugPrintln("=================================");
  debugPrintln("Sensor initialized! Fetching config...\n");

  // Fetch device configuration from database
  fetchDeviceConfig();

  // Apply configuration based on fetched settings
  //applyDeviceConfig();
  sensor.configLEDLight(sensor.eFALLLed, 1);         // Set HP LED switch, it will not light up even if the sensor detects a person present when set to 0.
  sensor.configLEDLight(sensor.eHPLed, 1);           // Set FALL LED switch, it will not light up even if the sensor detects a person falling when set to 0.
  sensor.dmInstallHeight(120);                   // Set installation height, it needs to be set according to the actual height of the surface from the sensor, unit: CM.
  sensor.dmUnmannedTime(1);                      // Set unattended time, when a person leaves the sensor detection range, the sensor delays a period of time before outputting a no person status, unit: seconds.
  // Note: fall time, residence time/switch, and fall sensitivity are now applied
  // via applyDeviceConfig() using values fetched from the database.
  sensor.sensorRet();                            // Module reset, must perform sensorRet after setting data, otherwise the sensor may not be usable.

  debugPrintln("\n=================================");
  debugPrintln("Monitoring active!");
  debugPrintln("Firmware version: " + String(FIRMWARE_VERSION));
  debugPrintln("Calibrating sensor (30 seconds)...");

  // Report firmware version to database
  String versionJson = "{\"firmware_version\":\"" + String(FIRMWARE_VERSION) + "\"}";
  db.update(SUPABASE_TABLE).eq("device_id", DEVICE_ID).doUpdate(versionJson);

  // Wait 30 seconds for mmWave sensor calibration
  delay(30000);
  debugPrintln("Calibration complete! Starting data collection...");

  startTime = millis();
  lastConfigFetchTime = millis();
  lastConfigCheckTime = millis();
  lastOtaCheckTime = millis() - deviceConfig.otaCheckIntervalMs + 60000;  // Check in 1 minute
}

// Sample pressure sensor and detect door events
void samplePressure() {
  // Skip if sensor not initialized
  if (!dpsInitialized) {
    return;
  }

  unsigned long currentTime = millis();

  // Sample at 10 Hz (every 100ms)
  if (currentTime - lastPressureReadTime < PRESSURE_SAMPLE_INTERVAL) {
    return;
  }

  lastPressureReadTime = currentTime;

  // Read pressure and temperature
  sensors_event_t temp_event, pressure_event;
  if (dps.getEvents(&temp_event, &pressure_event)) {
    currentPressure = pressure_event.pressure;
    currentTemperature = temp_event.temperature;

    // Calculate pressure change
    float pressureChange = abs(currentPressure - lastPressure);

    // Detect door event (rapid pressure change)
    if (pressureChange > DOOR_EVENT_THRESHOLD) {
      doorEventsCount++;
      debugPrint("[DOOR EVENT] Pressure change: ");
      debugPrint(pressureChange, 2);
      debugPrint(" hPa (");
      debugPrint(lastPressure, 2);
      debugPrint(" -> ");
      debugPrint(currentPressure, 2);
      debugPrintln(")");
    }

    lastPressure = currentPressure;
  }
}

// Handle serial commands from USB Serial Monitor
void handleSerialCommands() {
  static String commandBuffer = "";

  while (USB_SERIAL.available()) {
    char c = USB_SERIAL.read();

    // Echo the character for feedback
    debugWrite(c);

    if (c == '\n' || c == '\r') {
      // Process command when Enter is pressed
      commandBuffer.trim();

      if (commandBuffer.length() > 0) {
        processCommand(commandBuffer);
        commandBuffer = "";
      }
    } else {
      commandBuffer += c;
    }
  }
}

// Process a serial command
void processCommand(const String& cmd) {
  debugPrintln(); // New line after command

  if (cmd.equalsIgnoreCase("CLEAR_WIFI") || cmd.equalsIgnoreCase("RESET_WIFI")) {
    debugPrintln("\n=== CLEARING WIFI CREDENTIALS ===");
    clearWiFiCredentials();
    debugPrintln("WiFi credentials erased from NVS");
    debugPrintln("Rebooting into BLE provisioning mode...");
    debugFlush();
    delay(1000);
    ESP.restart();
  }
  else if (cmd.equalsIgnoreCase("HELP") || cmd.equals("?")) {
    debugPrintln("\n=== AVAILABLE COMMANDS ===");
    debugPrintln("CLEAR_WIFI  - Clear stored WiFi credentials and reboot into BLE mode");
    debugPrintln("RESET_WIFI  - Same as CLEAR_WIFI");
    debugPrintln("STATUS      - Show device status");
    debugPrintln("RESTART     - Restart the device");
    debugPrintln("HELP or ?   - Show this help message");
    debugPrintln("==========================\n");
  }
  else if (cmd.equalsIgnoreCase("STATUS")) {
    debugPrintln("\n=== DEVICE STATUS ===");
    debugPrint("Firmware: ");
    debugPrintln(FIRMWARE_VERSION);
    debugPrint("Device: ");
    debugPrintln(DEVICE_MODEL);
    debugPrint("WiFi SSID: ");
    debugPrintln(WiFi.SSID());
    debugPrint("WiFi IP: ");
    debugPrintln(WiFi.localIP());
    debugPrint("MAC Address: ");
    debugPrintln(WiFi.macAddress());
    debugPrint("Mode: ");
    debugPrintln(deviceConfig.operationalMode);
    debugPrint("Uptime: ");
    debugPrint(millis() / 1000);
    debugPrintln(" seconds");
    debugPrintln("====================\n");
  }
  else if (cmd.equalsIgnoreCase("RESTART") || cmd.equalsIgnoreCase("REBOOT")) {
    debugPrintln("Restarting device...");
    debugFlush();
    delay(1000);
    ESP.restart();
  }
  else {
    debugPrint("Unknown command: ");
    debugPrintln(cmd);
    debugPrintln("Type 'HELP' for available commands");
  }
}

void loop() {
  // Handle serial commands
  handleSerialCommands();

  // Sample pressure sensor at 10 Hz
  samplePressure();

  // Update NeoPixel if in error state (for blinking)
  if (currentError != ERROR_NONE) {
    updateNeoPixelError();
  }

  // Check WiFi connection and reconnect if needed (tiered backoff strategy)
  if (WiFi.status() != WL_CONNECTED) {
    currentError = ERROR_WIFI_DISCONNECTED;
    updateNeoPixelError();  // Show error via NeoPixel

    unsigned long currentTime = millis();

    // Track when WiFi was first lost
    if (wifiDisconnectedSince == 0) {
      wifiDisconnectedSince = currentTime;
    }

    // Calculate how long WiFi has been disconnected
    unsigned long disconnectedDuration = currentTime - wifiDisconnectedSince;

    // Determine reconnection interval based on disconnect duration
    unsigned long reconnectInterval;
    if (disconnectedDuration < 5 * 60 * 1000) {
      // First 5 minutes: aggressive reconnection every 10 seconds
      reconnectInterval = WIFI_RECONNECT_INTERVAL_INITIAL;
    } else if (disconnectedDuration < 10 * 60 * 1000) {
      // 5-10 minutes: moderate reconnection every 20 seconds
      reconnectInterval = WIFI_RECONNECT_INTERVAL_MEDIUM;
    } else {
      // After 10 minutes: relaxed reconnection every 30 seconds
      reconnectInterval = WIFI_RECONNECT_INTERVAL_LONG;
    }

    // Only attempt reconnection at the calculated interval
    if (currentTime - lastWiFiReconnectAttempt >= reconnectInterval) {
      lastWiFiReconnectAttempt = currentTime;

      // Log which interval we're using
      debugPrint("WiFi disconnected for ");
      debugPrint(disconnectedDuration / 1000);
      debugPrint("s. Attempting reconnection (interval: ");
      debugPrint(reconnectInterval / 1000);
      debugPrintln("s)...");

      connectWiFi();

      // Check if reconnection succeeded
      if (WiFi.status() == WL_CONNECTED) {
        currentError = ERROR_NONE;  // Clear error
        wifiDisconnectedSince = 0;  // Reset disconnect timer
        debugPrintln("✓ WiFi reconnected successfully!");
      } else {
        debugPrint("✗ Reconnection failed - will retry in ");
        debugPrint(reconnectInterval / 1000);
        debugPrintln(" seconds");
      }
    }
  } else {
    // WiFi is connected - clear any disconnect error and reset timer
    if (currentError == ERROR_WIFI_DISCONNECTED) {
      currentError = ERROR_NONE;
    }
    wifiDisconnectedSince = 0;  // Reset disconnect timer when connected
  }

  unsigned long currentTime = millis();

  // Resync time every 5 minutes
  if (currentTime - lastTimeSyncMillis >= TIME_SYNC_INTERVAL) {
    lastTimeSyncMillis = currentTime;
    debugPrintln("Resyncing time with NTP...");
    configTime(GMT_OFFSET_SEC, DAYLIGHT_OFFSET_SEC, NTP_SERVER1, NTP_SERVER2, NTP_SERVER3);
  }

  // Periodic config check every 60 seconds
  if (currentTime - lastConfigCheckTime >= 60000) {
    lastConfigCheckTime = currentTime;
    debugPrintln("\n[Periodic Config Check]");
    fetchDeviceConfig();
  }

  // Periodic OTA check (interval configurable from database, default 1 hour)
  if (currentTime - lastOtaCheckTime >= deviceConfig.otaCheckIntervalMs) {
    lastOtaCheckTime = currentTime;
    checkForFirmwareUpdate();
  }

  // Interspersed data collection: critical data + one supplemental field
  // Both modes: every 10 seconds
  if (currentTime - lastQuickDataTime >= getDataInterval()) {
    lastQuickDataTime = currentTime;
    collectAndUploadQuickData();
  }
}

// Get current timestamp in ISO 8601 UTC format
String getISOTimestamp() {
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) {
    return "1970-01-01T00:00:00Z"; // Return epoch if time not set
  }

  char timestamp[25];
  // Format as UTC with Z suffix (Zulu time)
  strftime(timestamp, sizeof(timestamp), "%Y-%m-%dT%H:%M:%SZ", &timeinfo);

  return String(timestamp);
}

// Update NeoPixel to show error state
void updateNeoPixelError() {
  unsigned long currentTime = millis();

  switch (currentError) {
    case ERROR_WIFI_DISCONNECTED:
      // Red blinking (500ms interval)
      if (currentTime - lastErrorBlinkTime >= 500) {
        lastErrorBlinkTime = currentTime;
        errorBlinkState = !errorBlinkState;
        if (errorBlinkState) {
          pixel.setPixelColor(0, pixel.Color(255, 0, 0));  // Red
          pixel.setBrightness(100);
        } else {
          pixel.setPixelColor(0, pixel.Color(0, 0, 0));  // Off
        }
        pixel.show();
      }
      break;

    case ERROR_UPLOAD_FAILED:
      // Solid orange
      pixel.setPixelColor(0, pixel.Color(255, 100, 0));  // Orange
      pixel.setBrightness(80);
      pixel.show();
      break;

    case ERROR_SENSOR_FAILED:
      // Solid purple
      pixel.setPixelColor(0, pixel.Color(128, 0, 255));  // Purple
      pixel.setBrightness(80);
      pixel.show();
      break;

    case ERROR_NONE:
      // No error - will be handled by normal operation
      break;
  }
}

// Update NeoPixel based on movement (normal operation)
void updateNeoPixel(uint16_t movement, uint16_t presence) {
  // Check for errors first - they take priority
  if (currentError != ERROR_NONE) {
    updateNeoPixelError();
    return;
  }

  // Normal operation
  if (presence == 0 && movement == 0) {
    // No presence and no movement - turn off
    pixel.setPixelColor(0, pixel.Color(0, 0, 0));
  } else {
    // Map movement (0-100) to brightness (0-255)
    uint8_t brightness = map(movement, 0, 100, 0, 255);

    // Use a blue/cyan color that varies with movement
    // Low movement: dim blue, High movement: bright cyan
    uint8_t blue = 255;
    uint8_t green = map(movement, 0, 100, 0, 128);  // Add green for brighter appearance

    pixel.setPixelColor(0, pixel.Color(0, green, blue));
    pixel.setBrightness(brightness);
  }
  pixel.show();
}

void connectWiFi() {
  // Try loading WiFi credentials from NVS first (BLE provisioned)
  WiFiCredentials creds;
  bool hasStoredCreds = loadWiFiCredentials(creds);

  String ssid, password;
  if (hasStoredCreds) {
    debugPrintln("Using WiFi credentials from NVS (BLE provisioned)");
    ssid = creds.ssid;
    password = creds.password;
  } else {
    debugPrintln("No stored credentials found, using config.h defaults");
    ssid = WIFI_SSID;
    password = WIFI_PASSWORD;
  }

  debugPrint("Connecting to WiFi: ");
  debugPrint(ssid);
  debugPrint("... ");

  WiFi.begin(ssid.c_str(), password.c_str());

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    delay(500);
    debugPrint(".");
    attempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    debugPrintln(" CONNECTED!");
    debugPrint("IP Address: ");
    debugPrintln(WiFi.localIP());
  } else {
    debugPrintln(" FAILED!");
    debugPrintln("⚠ WiFi connection failed - will retry automatically");
    debugPrintln("⚠ Credentials preserved - device will reconnect when network is available");
    // DO NOT delete credentials! Just keep retrying.
    // Network outages, router reboots, etc. should not require re-provisioning.
    // Credentials stay intact and device will reconnect automatically.
  }
}

// Quick data + one supplemental field (interspersed collection)
void collectAndUploadQuickData() {
  unsigned long sensorStartTime = millis();

  debugPrint("\n[DATA COLLECTION] ");

  // Build JSON with critical data
  String json = "{";
  json += "\"device_id\":\"" + String(DEVICE_ID) + "\",";
  json += "\"location\":\"" + String(LOCATION) + "\",";
  json += "\"sensor_mode\":\"" + deviceConfig.operationalMode + "\",";
  json += "\"device_timestamp\":\"" + getISOTimestamp() + "\",";
  json += "\"uptime_sec\":" + String((millis() - startTime) / 1000) + ",";

  if (deviceConfig.operationalMode == "fall_detection") {
    // === ALWAYS CHECK MOVEMENT AND PRESENCE ===
    uint16_t movement = sensor.smHumanData(DFRobot_HumanDetection::eHumanMovingRange);
    debugPrint("Movement: ");
    debugPrint(movement);

    if (deviceConfig.sensorQueryDelayMs > 0) delay(deviceConfig.sensorQueryDelayMs);

    uint16_t humanPresence = sensor.smHumanData(DFRobot_HumanDetection::eHumanPresence);
    debugPrint(", Presence: ");
    debugPrint(humanPresence);

    // Update NeoPixel based on movement and presence
    updateNeoPixel(movement, humanPresence);

    // Decide if we should send full data or keep-alive
    // Send full data if: movement detected OR presence detected
    bool hasActivity = (movement > 0 || humanPresence > 0);

    if (!hasActivity) {
      // No activity - send keep-alive every 30 seconds
      unsigned long currentTime = millis();
      if (currentTime - lastKeepAliveTime >= KEEP_ALIVE_INTERVAL) {
        lastKeepAliveTime = currentTime;

        debugPrintln(" → Keep-alive");

        // Check for fall state (safety)
        if (deviceConfig.sensorQueryDelayMs > 0) delay(deviceConfig.sensorQueryDelayMs);
        uint8_t fallState = sensor.getFallData(DFRobot_HumanDetection::eFallState);

        json += "\"data_type\":\"keep_alive\",";
        json += "\"body_movement\":0,";
        json += "\"human_existence\":0,";
        json += "\"fall_state\":" + String(fallState);

        // Add door events if any occurred
        if (doorEventsCount > 0) {
          json += ",\"door_event\":" + String(doorEventsCount);
        }

        // Add pressure and temperature every 10 minutes (only if sensor working)
        if (dpsInitialized && millis() - lastPressureUploadTime >= PRESSURE_UPLOAD_INTERVAL) {
          if (!isnan(currentPressure) && !isnan(currentTemperature)) {
            json += ",\"air_pressure_hpa\":" + String(currentPressure, 2);
            json += ",\"temperature_c\":" + String(currentTemperature, 2);
          }
        }

        json += "}";

        // Upload to database
        int httpCode = supabaseInsert(SUPABASE_TABLE, json);
        debugPrint((httpCode == 201) ? "[KEEP-ALIVE] ✓" : "[KEEP-ALIVE] ✗");
        if (fallState > 0) debugPrintln(" FALL!");
        else debugPrintln();
      }
      return; // Skip full data collection
    }

    // === ACTIVITY DETECTED - SEND FULL DATA ===
    debugPrintln(" → Full data");

    json += "\"data_type\":\"quick\",";
    json += "\"body_movement\":" + String(movement);
    json += ",\"human_existence\":" + String(humanPresence);

    // === MEDIUM MODE: ADD HUMAN MOVEMENT ===
    if (deviceConfig.dataCollectionMode == "medium") {
      if (deviceConfig.sensorQueryDelayMs > 0) delay(deviceConfig.sensorQueryDelayMs);

      uint16_t humanMovement = sensor.smHumanData(DFRobot_HumanDetection::eHumanMovement);
      debugPrint("Human Movement: ");
      debugPrintln(humanMovement);
      json += ",\"human_movement\":" + String(humanMovement);
    }

  } else {
    // === SLEEP MODE ===
    // Critical data - collected every cycle
    uint8_t heartRate = sensor.getHeartRate();
    if (deviceConfig.sensorQueryDelayMs > 0) delay(deviceConfig.sensorQueryDelayMs);

    uint16_t bodyMovement = sensor.smHumanData(DFRobot_HumanDetection::eHumanMovement);
    if (deviceConfig.sensorQueryDelayMs > 0) delay(deviceConfig.sensorQueryDelayMs);

    uint16_t humanPresence = sensor.smHumanData(DFRobot_HumanDetection::eHumanPresence);
    if (deviceConfig.sensorQueryDelayMs > 0) delay(deviceConfig.sensorQueryDelayMs);

    // Update NeoPixel based on movement (use bodyMovement for sleep mode)
    updateNeoPixel(bodyMovement, humanPresence);

    // Decide if we should send full data or keep-alive
    bool hasActivity = (humanPresence > 0 || bodyMovement > 0);

    if (!hasActivity) {
      // No activity - send keep-alive every 30 seconds
      unsigned long currentTime = millis();
      if (currentTime - lastKeepAliveTime >= KEEP_ALIVE_INTERVAL) {
        lastKeepAliveTime = currentTime;
        debugPrintln(" → Keep-alive");
        json += "\"data_type\":\"keep_alive\",";
        json += "\"human_presence\":0,";
        json += "\"heart_rate_bpm\":" + String(heartRate) + ",";
        json += "\"body_movement\":0";
        if (doorEventsCount > 0) {
          json += ",\"door_event\":" + String(doorEventsCount);
        }
        if (dpsInitialized && millis() - lastPressureUploadTime >= PRESSURE_UPLOAD_INTERVAL) {
          if (!isnan(currentPressure) && !isnan(currentTemperature)) {
            json += ",\"air_pressure_hpa\":" + String(currentPressure, 2);
            json += ",\"temperature_c\":" + String(currentTemperature, 2);
          }
        }
        json += "}";
        int httpCode = supabaseInsert(SUPABASE_TABLE, json);
        debugPrintln((httpCode == 201) ? "[KEEP-ALIVE] ✓" : "[KEEP-ALIVE] ✗");
      }
      return; // Skip full data collection
    }
    debugPrintln(" → Full data");

    json += "\"human_presence\":" + String(humanPresence) + ",";
    json += "\"heart_rate_bpm\":" + String(heartRate) + ",";
    json += "\"body_movement\":" + String(bodyMovement);

    // === SUPPLEMENTAL DATA ===
    if (!deviceConfig.enableSupplementalQueries || deviceConfig.supplementalCycleMode == "none") {
      // Skip supplemental queries
    } else if (deviceConfig.supplementalCycleMode == "all") {
      // Query all supplemental data every cycle
      uint8_t respirationRate = sensor.getBreatheValue();
      if (deviceConfig.sensorQueryDelayMs > 0) delay(deviceConfig.sensorQueryDelayMs);
      uint16_t humanMovingRange = sensor.smHumanData(DFRobot_HumanDetection::eHumanMovingRange);
      if (deviceConfig.sensorQueryDelayMs > 0) delay(deviceConfig.sensorQueryDelayMs);
      uint16_t inOrNotInBed = sensor.smSleepData(DFRobot_HumanDetection::eInOrNotInBed);
      if (deviceConfig.sensorQueryDelayMs > 0) delay(deviceConfig.sensorQueryDelayMs);
      uint16_t sleepState = sensor.smSleepData(DFRobot_HumanDetection::eSleepState);
      if (deviceConfig.sensorQueryDelayMs > 0) delay(deviceConfig.sensorQueryDelayMs);
      uint16_t abnormalStruggle = sensor.smSleepData(DFRobot_HumanDetection::eAbnormalStruggle);
      if (deviceConfig.sensorQueryDelayMs > 0) delay(deviceConfig.sensorQueryDelayMs);
      uint16_t unattendedState = sensor.smSleepData(DFRobot_HumanDetection::eUnattendedState);

      json += ",\"respiration_rate\":" + String(respirationRate);
      json += ",\"human_move\":" + String(humanMovingRange);
      json += ",\"in_bed\":" + String(inOrNotInBed);
      json += ",\"sleep_state\":" + String(sleepState);
      json += ",\"abnormal_struggle\":" + String(abnormalStruggle);
      json += ",\"unattended_state\":" + String(unattendedState);
    } else {
      // Rotating mode - cycle through supplemental queries
      switch (supplementalQueryIndex) {
      case 0: {
        uint8_t respirationRate = sensor.getBreatheValue();
        json += ",\"respiration_rate\":" + String(respirationRate);
        break;
      }
      case 1: {
        uint16_t humanMovingRange = sensor.smHumanData(DFRobot_HumanDetection::eHumanMovingRange);
        json += ",\"human_move\":" + String(humanMovingRange);
        break;
      }
      case 2: {
        uint16_t inOrNotInBed = sensor.smSleepData(DFRobot_HumanDetection::eInOrNotInBed);
        json += ",\"in_bed\":" + String(inOrNotInBed);
        break;
      }
      case 3: {
        uint16_t sleepState = sensor.smSleepData(DFRobot_HumanDetection::eSleepState);
        json += ",\"sleep_state\":" + String(sleepState);
        break;
      }
      case 4: {
        sSleepComposite composite = sensor.getSleepComposite();
        json += ",\"composite_presence\":" + String(composite.presence) + ",";
        json += "\"composite_sleep_state\":" + String(composite.sleepState) + ",";
        json += "\"composite_avg_respiration\":" + String(composite.averageRespiration) + ",";
        json += "\"composite_avg_heartbeat\":" + String(composite.averageHeartbeat) + ",";
        json += "\"composite_turn_over_count\":" + String(composite.turnoverNumber);
        break;
      }
      case 5: {
        sSleepComposite composite = sensor.getSleepComposite();
        json += ",\"stats_large_body_movement\":" + String(composite.largeBodyMove) + ",";
        json += "\"stats_minor_body_movement\":" + String(composite.minorBodyMove) + ",";
        json += "\"composite_apnea_events\":" + String(composite.apneaEvents);
        break;
      }
      case 6: {
        sSleepStatistics stats = sensor.getSleepStatistics();
        json += ",\"stats_sleep_quality_score\":" + String(stats.sleepQualityScore) + ",";
        json += "\"stats_sleep_time_min\":" + String(stats.sleepTime) + ",";
        json += "\"stats_wake_duration\":" + String(stats.wakeDuration);
        break;
      }
      case 7: {
        sSleepStatistics stats = sensor.getSleepStatistics();
        json += ",\"stats_light_sleep_pct\":" + String(stats.shallowSleepPercentage) + ",";
        json += "\"stats_deep_sleep_pct\":" + String(stats.deepSleepPercentage);
        break;
      }
      case 8: {
        uint16_t abnormalStruggle = sensor.smSleepData(DFRobot_HumanDetection::eAbnormalStruggle);
        json += ",\"abnormal_struggle\":" + String(abnormalStruggle);
        break;
      }
      case 9: {
        uint16_t unattendedState = sensor.smSleepData(DFRobot_HumanDetection::eUnattendedState);
        json += ",\"unattended_state\":" + String(unattendedState);
        break;
      }
      default: {
        // No additional query - just critical data
        break;
      }
    }

      // Increment and wrap for sleep mode (10 supplemental cycles) - only in rotating mode
      supplementalQueryIndex = (supplementalQueryIndex + 1) % 10;
    }
  }

  // Add pressure sensor data
  // Add door events if any occurred
  if (doorEventsCount > 0) {
    json += ",\"door_event\":" + String(doorEventsCount);
  }

  // Add pressure and temperature every 10 minutes (only if sensor working)
  if (dpsInitialized && millis() - lastPressureUploadTime >= PRESSURE_UPLOAD_INTERVAL) {
    if (!isnan(currentPressure) && !isnan(currentTemperature)) {
      json += ",\"air_pressure_hpa\":" + String(currentPressure, 2);
      json += ",\"temperature_c\":" + String(currentTemperature, 2);
    }
  }

  json += "}";

  unsigned long sensorReadTime = millis() - sensorStartTime;

  // Debug: Print JSON before upload
  debugPrintln("\n--- JSON DATA ---");
  debugPrintln(json);
  debugPrintln("-----------------");

  // Upload to Supabase (using direct HTTPClient instead of buggy ESPSupabase)
  unsigned long uploadStartTime = millis();
  debugPrint("Uploading... ");
  int httpCode = supabaseInsert(SUPABASE_TABLE, json);
  unsigned long uploadTime = millis() - uploadStartTime;

  if (httpCode == 201) {
    debugPrint("SUCCESS! ");
    // Reset door event counter after successful upload
    doorEventsCount = 0;

    // Update last pressure upload time if we sent pressure/temp data
    if (millis() - lastPressureUploadTime >= PRESSURE_UPLOAD_INTERVAL) {
      lastPressureUploadTime = millis();
    }

    // Clear upload error if it was set
    if (currentError == ERROR_UPLOAD_FAILED) {
      currentError = ERROR_NONE;
    }
    uploadFailCount = 0;  // Reset fail counter
  } else {
    debugPrint("FAILED (HTTP ");
    debugPrint(httpCode);
    debugPrintln(")");

    // Track upload failures
    uploadFailCount++;
    if (uploadFailCount >= 3) {
      // After 3 consecutive failures, show error
      currentError = ERROR_UPLOAD_FAILED;
      debugPrintln("WARNING: Multiple upload failures detected!");
    }
  }

  unsigned long totalTime = sensorReadTime + uploadTime;
  debugPrint("Read: ");
  debugPrint(sensorReadTime);
  debugPrint("ms, Upload: ");
  debugPrint(uploadTime);
  debugPrint("ms, Total: ");
  debugPrint(totalTime);
  debugPrintln("ms");
}

// Check if config was updated via web dashboard
bool checkConfigUpdated() {
  // Query just the config_updated flag
  db.urlQuery_reset();
  String response = db.from("moveometers").select("config_updated").eq("device_id", String(DEVICE_ID)).doSelect();

  if (response.length() > 0 && response != "[]") {
    // Check if config_updated is true
    int configIdx = response.indexOf("\"config_updated\":");
    if (configIdx > 0) {
      configIdx += 17;  // Skip past the key
      String value = response.substring(configIdx, configIdx + 4);
      return (value == "true");
    }
  }
  return false;
}

// Check for pending commands from web dashboard
String checkPendingCommand() {
  db.urlQuery_reset();
  String response = db.from("moveometers").select("pending_command").eq("device_id", String(DEVICE_ID)).doSelect();

  if (response.length() > 0 && response != "[]") {
    int cmdIdx = response.indexOf("\"pending_command\":\"");
    if (cmdIdx > 0) {
      cmdIdx += 19;  // Skip past the key
      int endIdx = response.indexOf("\"", cmdIdx);
      if (endIdx > cmdIdx) {
        return response.substring(cmdIdx, endIdx);
      }
    }
  }
  return "";
}

// Clear pending command after execution
void clearPendingCommand() {
  db.urlQuery_reset();
  String updateData = "{\"pending_command\":null}";
  db.update("moveometers").eq("device_id", String(DEVICE_ID)).doUpdate(updateData);
  debugPrintln("Pending command cleared.");
}

// Execute command from web dashboard
void executeCommand(String command) {
  debugPrint("\n⚡ Executing command: ");
  debugPrintln(command);

  if (command == "reconfigure") {
    debugPrintln("Reconfiguring sensor...");
   // applyDeviceConfig();
    debugPrintln("✅ Sensor reconfigured successfully!");

  } else if (command == "reset_sensor") {
    if (ENABLE_POWER_CONTROL) {
      debugPrintln("Performing hardware reset...");
      resetSensor();
      debugPrintln("✅ Sensor reset complete!");
    } else {
      debugPrintln("⚠️ Hardware reset not available (power control disabled)");
      debugPrintln("Performing soft reset (reconfigure) instead...");
     // applyDeviceConfig();
    }

  } else if (command == "reboot") {
    debugPrintln("Rebooting ESP32...");
    delay(1000);
    ESP.restart();

  } else {
    debugPrint("⚠️ Unknown command: ");
    debugPrintln(command);
  }

  clearPendingCommand();
}

// Clear the config_updated flag after syncing
void clearConfigUpdatedFlag() {
  db.urlQuery_reset();
  String updateData = "{\"config_updated\":false}";
  int httpCode = db.update("moveometers").eq("device_id", String(DEVICE_ID)).doUpdate(updateData);

  if (httpCode == 200 || httpCode == 204) {
    debugPrintln("Config updated flag cleared.");
  }
}

// Fetch device configuration from Supabase
void fetchDeviceConfig() {
  debugPrint("Fetching device config from database... ");

  // Query the moveometers table for this device using direct HTTP
  String response = supabaseSelect("moveometers", "device_id", DEVICE_ID);

  if (response.length() > 0 && response != "[]") {
    debugPrintln("SUCCESS!");
    debugPrintln("Config received:");
    debugPrintln(response);

    // Parse JSON response (basic parsing - could use ArduinoJson library for robust parsing)
    // Extract operational_mode
    int modeIdx = response.indexOf("\"operational_mode\":\"");
    if (modeIdx > 0) {
      modeIdx += 20; // Skip past the key
      int endIdx = response.indexOf("\"", modeIdx);
      deviceConfig.operationalMode = response.substring(modeIdx, endIdx);
      debugPrint("  Mode: ");
      debugPrintln(deviceConfig.operationalMode);
    }

    // Extract data_collection_mode
    int dataCollectionIdx = response.indexOf("\"data_collection_mode\":\"");
    if (dataCollectionIdx > 0) {
      dataCollectionIdx += 24; // Skip past the key
      int endIdx = response.indexOf("\"", dataCollectionIdx);
      deviceConfig.dataCollectionMode = response.substring(dataCollectionIdx, endIdx);
      debugPrint("  Data Collection Mode: ");
      debugPrintln(deviceConfig.dataCollectionMode);
    }

    // Extract fall_detection_interval_ms
    int fallIntervalIdx = response.indexOf("\"fall_detection_interval_ms\":");
    if (fallIntervalIdx > 0) {
      fallIntervalIdx += 30;
      int endIdx = response.indexOf(",", fallIntervalIdx);
      if (endIdx < 0) endIdx = response.indexOf("}", fallIntervalIdx);
      deviceConfig.fallDetectionIntervalMs = response.substring(fallIntervalIdx, endIdx).toInt();
      debugPrint("  Fall Detection Interval: ");
      debugPrint(deviceConfig.fallDetectionIntervalMs);
      debugPrintln(" ms");
    }

    // Extract sleep_mode_interval_ms
    int sleepIntervalIdx = response.indexOf("\"sleep_mode_interval_ms\":");
    if (sleepIntervalIdx > 0) {
      sleepIntervalIdx += 25;
      int endIdx = response.indexOf(",", sleepIntervalIdx);
      if (endIdx < 0) endIdx = response.indexOf("}", sleepIntervalIdx);
      deviceConfig.sleepModeIntervalMs = response.substring(sleepIntervalIdx, endIdx).toInt();
      debugPrint("  Sleep Mode Interval: ");
      debugPrint(deviceConfig.sleepModeIntervalMs);
      debugPrintln(" ms");
    }

    // Extract config_check_interval_ms
    int configCheckIdx = response.indexOf("\"config_check_interval_ms\":");
    if (configCheckIdx > 0) {
      configCheckIdx += 27;
      int endIdx = response.indexOf(",", configCheckIdx);
      if (endIdx < 0) endIdx = response.indexOf("}", configCheckIdx);
      deviceConfig.configCheckIntervalMs = response.substring(configCheckIdx, endIdx).toInt();
      debugPrint("  Config Check Interval: ");
      debugPrint(deviceConfig.configCheckIntervalMs);
      debugPrintln(" ms");
    }

    // Extract ota_check_interval_ms
    int otaCheckIdx = response.indexOf("\"ota_check_interval_ms\":");
    if (otaCheckIdx > 0) {
      otaCheckIdx += 24;
      int endIdx = response.indexOf(",", otaCheckIdx);
      if (endIdx < 0) endIdx = response.indexOf("}", otaCheckIdx);
      deviceConfig.otaCheckIntervalMs = response.substring(otaCheckIdx, endIdx).toInt();
      debugPrint("  OTA Check Interval: ");
      debugPrint(deviceConfig.otaCheckIntervalMs / 60000);
      debugPrintln(" minutes");
    }

    // Extract sensor_query_delay_ms
    int queryDelayIdx = response.indexOf("\"sensor_query_delay_ms\":");
    if (queryDelayIdx > 0) {
      queryDelayIdx += 24;
      int endIdx = response.indexOf(",", queryDelayIdx);
      if (endIdx < 0) endIdx = response.indexOf("}", queryDelayIdx);
      deviceConfig.sensorQueryDelayMs = response.substring(queryDelayIdx, endIdx).toInt();
      debugPrint("  Sensor Query Delay: ");
      debugPrint(deviceConfig.sensorQueryDelayMs);
      debugPrintln(" ms");
    }

    // Extract query_retry_attempts
    int retryAttemptsIdx = response.indexOf("\"query_retry_attempts\":");
    if (retryAttemptsIdx > 0) {
      retryAttemptsIdx += 23;
      int endIdx = response.indexOf(",", retryAttemptsIdx);
      if (endIdx < 0) endIdx = response.indexOf("}", retryAttemptsIdx);
      deviceConfig.queryRetryAttempts = response.substring(retryAttemptsIdx, endIdx).toInt();
      debugPrint("  Query Retry Attempts: ");
      debugPrintln(deviceConfig.queryRetryAttempts);
    }

    // Extract query_retry_delay_ms
    int retryDelayIdx = response.indexOf("\"query_retry_delay_ms\":");
    if (retryDelayIdx > 0) {
      retryDelayIdx += 23;
      int endIdx = response.indexOf(",", retryDelayIdx);
      if (endIdx < 0) endIdx = response.indexOf("}", retryDelayIdx);
      deviceConfig.queryRetryDelayMs = response.substring(retryDelayIdx, endIdx).toInt();
      debugPrint("  Query Retry Delay: ");
      debugPrint(deviceConfig.queryRetryDelayMs);
      debugPrintln(" ms");
    }

    // Extract enable_supplemental_queries
    int enableSuppIdx = response.indexOf("\"enable_supplemental_queries\":");
    if (enableSuppIdx > 0) {
      enableSuppIdx += 30;
      deviceConfig.enableSupplementalQueries = (response.substring(enableSuppIdx, enableSuppIdx + 4) == "true");
      debugPrint("  Supplemental Queries: ");
      debugPrintln(deviceConfig.enableSupplementalQueries ? "Enabled" : "Disabled");
    }

    // Extract supplemental_cycle_mode
    int cycleModeIdx = response.indexOf("\"supplemental_cycle_mode\":\"");
    if (cycleModeIdx > 0) {
      cycleModeIdx += 27;
      int endIdx = response.indexOf("\"", cycleModeIdx);
      deviceConfig.supplementalCycleMode = response.substring(cycleModeIdx, endIdx);
      debugPrint("  Supplemental Cycle Mode: ");
      debugPrintln(deviceConfig.supplementalCycleMode);
    }

    // Extract install_height_cm
    int heightIdx = response.indexOf("\"install_height_cm\":");
    if (heightIdx > 0) {
      heightIdx += 20;
      int endIdx = response.indexOf(",", heightIdx);
      if (endIdx < 0) endIdx = response.indexOf("}", heightIdx);
      deviceConfig.installHeightCm = response.substring(heightIdx, endIdx).toInt();
      debugPrint("  Install Height: ");
      debugPrint(deviceConfig.installHeightCm);
      debugPrintln(" cm");
    }

    // Extract fall_sensitivity
    int sensIdx = response.indexOf("\"fall_sensitivity\":");
    if (sensIdx > 0) {
      sensIdx += 19;
      int endIdx = response.indexOf(",", sensIdx);
      if (endIdx < 0) endIdx = response.indexOf("}", sensIdx);
      deviceConfig.fallSensitivity = response.substring(sensIdx, endIdx).toInt();
      debugPrint("  Fall Sensitivity: ");
      debugPrintln(deviceConfig.fallSensitivity);
    }

    // Extract fall_time_sec
    int fallTimeIdx = response.indexOf("\"fall_time_sec\":");
    if (fallTimeIdx > 0) {
      fallTimeIdx += 16;
      int endIdx = response.indexOf(",", fallTimeIdx);
      if (endIdx < 0) endIdx = response.indexOf("}", fallTimeIdx);
      deviceConfig.fallTimeSec = response.substring(fallTimeIdx, endIdx).toInt();
      debugPrint("  Fall Time: ");
      debugPrint(deviceConfig.fallTimeSec);
      debugPrintln(" sec");
    }

    // Extract residence_time_sec
    int residTimeIdx = response.indexOf("\"residence_time_sec\":");
    if (residTimeIdx > 0) {
      residTimeIdx += 21;
      int endIdx = response.indexOf(",", residTimeIdx);
      if (endIdx < 0) endIdx = response.indexOf("}", residTimeIdx);
      deviceConfig.residenceTimeSec = response.substring(residTimeIdx, endIdx).toInt();
      debugPrint("  Residence Time: ");
      debugPrint(deviceConfig.residenceTimeSec);
      debugPrintln(" sec");
    }

    // Extract residence_switch
    int residSwIdx = response.indexOf("\"residence_switch\":");
    if (residSwIdx > 0) {
      residSwIdx += 19;
      deviceConfig.residenceSwitch = (response.substring(residSwIdx, residSwIdx + 4) == "true");
      debugPrint("  Residence Detection: ");
      debugPrintln(deviceConfig.residenceSwitch ? "Enabled" : "Disabled");
    }

    // Extract position_tracking_enabled
    int trackIdx = response.indexOf("\"position_tracking_enabled\":");
    if (trackIdx > 0) {
      trackIdx += 28;
      deviceConfig.positionTrackingEnabled = (response.substring(trackIdx, trackIdx + 4) == "true");
      debugPrint("  Position Tracking: ");
      debugPrintln(deviceConfig.positionTrackingEnabled ? "Enabled" : "Disabled");
    }

    // Extract seated_distance_threshold_cm
    int seatedDistIdx = response.indexOf("\"seated_distance_threshold_cm\":");
    if (seatedDistIdx > 0) {
      seatedDistIdx += 31;
      int endIdx = response.indexOf(",", seatedDistIdx);
      if (endIdx < 0) endIdx = response.indexOf("}", seatedDistIdx);
      deviceConfig.seatedDistanceThresholdCm = response.substring(seatedDistIdx, endIdx).toInt();
      debugPrint("  Seated Distance Threshold: ");
      debugPrint(deviceConfig.seatedDistanceThresholdCm);
      debugPrintln(" cm");
    }

    // Extract motion_distance_threshold_cm
    int motionDistIdx = response.indexOf("\"motion_distance_threshold_cm\":");
    if (motionDistIdx > 0) {
      motionDistIdx += 31;
      int endIdx = response.indexOf(",", motionDistIdx);
      if (endIdx < 0) endIdx = response.indexOf("}", motionDistIdx);
      deviceConfig.motionDistanceThresholdCm = response.substring(motionDistIdx, endIdx).toInt();
      debugPrint("  Motion Distance Threshold: ");
      debugPrint(deviceConfig.motionDistanceThresholdCm);
      debugPrintln(" cm");
    }

  } else {
    debugPrintln("FAILED or device not found in database!");
    debugPrintln("Using default configuration.");
  }
}

// Apply fetched configuration to sensor
void applyDeviceConfig() {
  debugPrintln("\nApplying configuration to sensor...");

  // Apply operational mode
  if (deviceConfig.operationalMode == "sleep") {
    debugPrint("  Configuring SLEEP MODE... ");
    if (sensor.configWorkMode(DFRobot_HumanDetection::eSleepMode) != 0) {
      debugPrintln("FAILED!");
    } else {
      debugPrintln("SUCCESS!");
    }
  } else {
    debugPrint("  Configuring FALL DETECTION MODE... ");
    if (sensor.configWorkMode(DFRobot_HumanDetection::eFallingMode) != 0) {
      debugPrintln("FAILED!");
    } else {
      debugPrintln("SUCCESS!");
    }

    // Apply fall sensitivity (0-3, 3 = most sensitive)
    debugPrint("  Setting fall sensitivity to ");
    debugPrint(deviceConfig.fallSensitivity);
    debugPrint("... ");
    sensor.dmFallConfig(DFRobot_HumanDetection::eFallSensitivityC, deviceConfig.fallSensitivity);
    delay(100);
    debugPrintln("DONE!");

    // Apply fall time (delay before reporting a fall)
    debugPrint("  Setting fall time to ");
    debugPrint(deviceConfig.fallTimeSec);
    debugPrint(" sec... ");
    sensor.dmFallTime(deviceConfig.fallTimeSec);
    delay(100);
    debugPrintln("DONE!");

    // Apply static residency switch and time
    debugPrint("  Residency detection: ");
    debugPrint(deviceConfig.residenceSwitch ? "ON" : "OFF");
    debugPrint(", time=");
    debugPrint(deviceConfig.residenceTimeSec);
    debugPrint(" sec... ");
    sensor.dmFallConfig(DFRobot_HumanDetection::eResidenceSwitchC, deviceConfig.residenceSwitch ? 1 : 0);
    delay(50);
    sensor.dmFallConfig(DFRobot_HumanDetection::eResidenceTime, deviceConfig.residenceTimeSec);
    delay(100);
    debugPrintln("DONE!");

    // Apply human detection thresholds (only in fall mode)
    debugPrint("  Setting seated distance threshold to ");
    debugPrint(deviceConfig.seatedDistanceThresholdCm);
    debugPrint(" cm... ");
    sensor.dmHumanConfig(DFRobot_HumanDetection::eSeatedHorizontalDistanceC, deviceConfig.seatedDistanceThresholdCm);
    delay(100);
    debugPrintln("DONE!");

    debugPrint("  Setting motion distance threshold to ");
    debugPrint(deviceConfig.motionDistanceThresholdCm);
    debugPrint(" cm... ");
    sensor.dmHumanConfig(DFRobot_HumanDetection::eMotionHorizontalDistanceC, deviceConfig.motionDistanceThresholdCm);
    delay(100);
    debugPrintln("DONE!");
  }

  // Apply installation height
  debugPrint("  Setting installation height to ");
  debugPrint(deviceConfig.installHeightCm);
  debugPrint(" cm... ");
  sensor.dmInstallHeight(deviceConfig.installHeightCm);
  delay(100);
  debugPrintln("DONE!");

  // Enable LED for debugging (set to 1 to disable, 0 to enable)
  debugPrint("  Enabling sensor LED for debugging... ");
  sensor.configLEDLight(DFRobot_HumanDetection::eFALLLed, 0);  // 0 = LED ON
  debugPrintln("DONE!");

  debugPrintln("Configuration applied successfully!\n");
}

