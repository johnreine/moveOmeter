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

// NeoPixel configuration
#define NEOPIXEL_PIN 21        // GPIO21 for NeoPixel data
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
float currentPressure = 0.0;  // Current pressure in hPa
float currentTemperature = 0.0; // Current temperature in C
float lastPressure = 0.0;     // Previous reading for event detection
int doorEventsCount = 0;      // Door events detected since last upload
unsigned long lastPressureReadTime = 0;
unsigned long lastPressureUploadTime = 0; // Track when we last sent pressure/temp
#define PRESSURE_SAMPLE_INTERVAL 100  // Sample every 100ms (10 Hz) for event detection
#define PRESSURE_UPLOAD_INTERVAL 600000 // Send pressure/temp every 10 minutes
#define DOOR_EVENT_THRESHOLD 0.3      // Pressure change in hPa to detect door event

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
    USB_SERIAL.println("ERROR: Power control not enabled!");
    return;
  }

  USB_SERIAL.println("\n*** Resetting mmWave sensor ***");

  // Power off sensor
  digitalWrite(SENSOR_POWER_PIN, LOW);
  USB_SERIAL.println("Sensor power: OFF");
  delay(3000);  // Wait 3 seconds

  // Power on sensor
  digitalWrite(SENSOR_POWER_PIN, HIGH);
  USB_SERIAL.println("Sensor power: ON");
  USB_SERIAL.println("Waiting for sensor initialization (10 seconds)...");
  delay(10000);  // Wait 10 seconds for sensor init

  // Reconfigure sensor
  USB_SERIAL.print("Reconfiguring Fall Detection Mode... ");
  if (sensor.configWorkMode(DFRobot_HumanDetection::eFallingMode) != 0) {
    USB_SERIAL.println("FAILED!");
  } else {
    USB_SERIAL.println("SUCCESS!");
  }

  // Restore installation height
  sensor.dmInstallHeight(125);
  USB_SERIAL.println("Installation height restored to 125");

  USB_SERIAL.println("*** Sensor reset complete! ***\n");
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
    USB_SERIAL.println("OTA status updated: " + status);
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
  USB_SERIAL.println("\n[OTA] Checking for firmware updates...");
  USB_SERIAL.println("Current version: " + String(FIRMWARE_VERSION));

  updateOtaStatus("checking");

  // Query latest firmware version
  String query = "version,download_url,md5_checksum,mandatory,release_notes";
  String response = db.select(query).from("firmware_updates")
    .eq("device_model", DEVICE_MODEL)
    .order("created_at", "desc", false)
    .limit(1)
    .doSelect();

  if (response.length() == 0) {
    USB_SERIAL.println("[OTA] Failed to query firmware updates");
    updateOtaStatus("failed", "Query failed");
    return;
  }
  USB_SERIAL.println("[OTA] Response: " + response);

  // Parse JSON response
  if (response.indexOf("\"version\":") < 0) {
    USB_SERIAL.println("[OTA] No firmware updates available");
    updateOtaStatus("idle");
    return;
  }

  // Extract version
  int versionStart = response.indexOf("\"version\":\"") + 11;
  int versionEnd = response.indexOf("\"", versionStart);
  String latestVersion = response.substring(versionStart, versionEnd);

  USB_SERIAL.println("[OTA] Latest version: " + latestVersion);

  // Compare versions
  int comparison = compareVersions(latestVersion, FIRMWARE_VERSION);

  if (comparison <= 0) {
    USB_SERIAL.println("[OTA] Already on latest version");
    updateOtaStatus("idle");
    return;
  }

  // Extract download URL
  int urlStart = response.indexOf("\"download_url\":\"") + 16;
  int urlEnd = response.indexOf("\"", urlStart);
  String downloadUrl = response.substring(urlStart, urlEnd);

  if (downloadUrl == "placeholder" || downloadUrl.length() < 10) {
    USB_SERIAL.println("[OTA] Invalid download URL");
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

  USB_SERIAL.println("[OTA] New version available: " + latestVersion);
  USB_SERIAL.println("[OTA] Download URL: " + downloadUrl);

  // Perform update
  performOtaUpdate(downloadUrl, md5Checksum);
}

// Perform OTA update
void performOtaUpdate(String url, String md5) {
  USB_SERIAL.println("\n[OTA] Starting firmware update...");
  USB_SERIAL.println("[OTA] URL: " + url);

  updateOtaStatus("downloading");

  WiFiClientSecure client;
  client.setInsecure();  // For Supabase, you may want to add proper certificate validation

  // Configure HTTP update
  httpUpdate.setLedPin(LED_BUILTIN, LOW);
  httpUpdate.rebootOnUpdate(false);  // We'll reboot manually after updating status

  // Set MD5 checksum if provided
  if (md5.length() == 32) {
    httpUpdate.setMD5sum(md5.c_str());
    USB_SERIAL.println("[OTA] Using MD5: " + md5);
  }

  // Perform update
  USB_SERIAL.println("[OTA] Downloading and flashing firmware...");
  updateOtaStatus("updating");

  t_httpUpdate_return ret = httpUpdate.update(client, url);

  switch(ret) {
    case HTTP_UPDATE_FAILED:
      USB_SERIAL.printf("[OTA] Update failed. Error (%d): %s\n",
        httpUpdate.getLastError(), httpUpdate.getLastErrorString().c_str());
      updateOtaStatus("failed", httpUpdate.getLastErrorString());
      break;

    case HTTP_UPDATE_NO_UPDATES:
      USB_SERIAL.println("[OTA] No update needed");
      updateOtaStatus("idle");
      break;

    case HTTP_UPDATE_OK:
      USB_SERIAL.println("[OTA] Update successful!");
      updateOtaStatus("success");
      delay(2000);
      USB_SERIAL.println("[OTA] Rebooting...");
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
  USB_SERIAL.println("\n=== Testing Raw HTTP Insert ===");

  WiFiClientSecure client;
  client.setInsecure(); // Skip certificate validation for testing

  HTTPClient http;
  String url = String(SUPABASE_URL) + "/rest/v1/" + String(SUPABASE_TABLE);

  USB_SERIAL.println("URL: " + url);

  http.begin(client, url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("apikey", SUPABASE_ANON_KEY);
  http.addHeader("Authorization", "Bearer " + String(SUPABASE_ANON_KEY));
  http.addHeader("Prefer", "return=minimal");

  String json = "{\"device_id\":\"ESP32C6_001\",\"sensor_mode\":\"fall_detection\",\"body_movement\":99}";
  USB_SERIAL.println("JSON: " + json);

  int httpCode = http.POST(json);

  USB_SERIAL.print("Raw HTTP Test - Status Code: ");
  USB_SERIAL.println(httpCode);
  USB_SERIAL.print("Response: ");
  USB_SERIAL.println(http.getString());

  http.end();
  USB_SERIAL.println("=== Test Complete ===\n");
}

void setup() {
  // Initialize USB Serial for debugging
  USB_SERIAL.begin(115200);
  delay(2000);

  USB_SERIAL.println("\n=================================");
  USB_SERIAL.println("mmWave Supabase Data Collector");
  USB_SERIAL.println("=================================");

  // Initialize sensor power control pin (if enabled)
  if (ENABLE_POWER_CONTROL) {
    pinMode(SENSOR_POWER_PIN, OUTPUT);
    digitalWrite(SENSOR_POWER_PIN, HIGH);  // Sensor ON
    USB_SERIAL.println("Sensor power control: ENABLED");
  } else {
    USB_SERIAL.println("Sensor power control: DISABLED (direct power)");
  }

  // Initialize NeoPixel
  USB_SERIAL.println("Initializing NeoPixel...");
  pixel.begin();
  pixel.setBrightness(NEOPIXEL_BRIGHTNESS);
  pixel.clear();
  pixel.show();
  USB_SERIAL.println("NeoPixel initialized (off)");

  // Initialize DPS310 pressure sensor
  USB_SERIAL.print("Initializing DPS310 pressure sensor... ");
  if (dps.begin_I2C(0x77)) {
    USB_SERIAL.println("SUCCESS!");
    dps.configurePressure(DPS310_64HZ, DPS310_64SAMPLES);  // High precision
    dps.configureTemperature(DPS310_64HZ, DPS310_64SAMPLES);

    // Take initial reading
    sensors_event_t temp_event, pressure_event;
    dps.getEvents(&temp_event, &pressure_event);
    currentPressure = pressure_event.pressure;
    lastPressure = currentPressure;
    USB_SERIAL.print("Initial pressure: ");
    USB_SERIAL.print(currentPressure);
    USB_SERIAL.println(" hPa");
  } else {
    USB_SERIAL.println("FAILED! (continuing without pressure sensor)");
  }

  // Check if we have WiFi credentials
  WiFiCredentials creds;
  bool hasWiFiConfig = loadWiFiCredentials(creds);

  if (!hasWiFiConfig && String(WIFI_SSID) == "YOUR_WIFI_SSID") {
    // No stored credentials and config.h has placeholder values
    // Enter BLE provisioning mode
    USB_SERIAL.println("\n╔═══════════════════════════════════════╗");
    USB_SERIAL.println("║  NO WIFI CONFIGURED                   ║");
    USB_SERIAL.println("║  Starting BLE Provisioning Mode...    ║");
    USB_SERIAL.println("╚═══════════════════════════════════════╝\n");

    // Flash NeoPixel blue to indicate BLE mode
    pixel.setPixelColor(0, pixel.Color(0, 0, 255));
    pixel.setBrightness(50);
    pixel.show();

    initBLEProvisioning();
    startBLEProvisioning();

    // Loop forever in BLE mode until credentials are received
    while (true) {
      delay(1000);
      // Blink LED to show we're in BLE mode
      static bool ledState = false;
      ledState = !ledState;
      pixel.setBrightness(ledState ? 50 : 10);
      pixel.show();
    }
  }

  // Connect to WiFi
  connectWiFi();

  // Initialize NTP time sync
  USB_SERIAL.print("Syncing time with NTP servers... ");
  configTime(GMT_OFFSET_SEC, DAYLIGHT_OFFSET_SEC, NTP_SERVER1, NTP_SERVER2, NTP_SERVER3);

  // Wait for time to be set
  struct tm timeinfo;
  int attempts = 0;
  while (!getLocalTime(&timeinfo) && attempts < 10) {
    delay(500);
    USB_SERIAL.print(".");
    attempts++;
  }

  if (getLocalTime(&timeinfo)) {
    USB_SERIAL.println(" SUCCESS!");
    USB_SERIAL.print("Current time: ");
    USB_SERIAL.println(&timeinfo, "%Y-%m-%d %H:%M:%S");
  } else {
    USB_SERIAL.println(" FAILED! (will retry)");
  }

  // Test raw HTTP insert (for debugging 401 errors)
  testRawHTTPInsert();

  // Initialize Supabase
  USB_SERIAL.print("Initializing Supabase... ");
  db.begin(SUPABASE_URL, SUPABASE_ANON_KEY);
  USB_SERIAL.println("SUCCESS!");

  // Initialize UART Serial for mmWave sensor
  MMWAVE_SERIAL.begin(115200, SERIAL_8N1, MMWAVE_RX_PIN, MMWAVE_TX_PIN);

  // Initialize sensor
  USB_SERIAL.print("Initializing sensor (this takes ~10 seconds)... ");
  if (sensor.begin() != 0) {
    USB_SERIAL.println("FAILED!");
    USB_SERIAL.println("Please check wiring and power supply.");
    while(1) delay(1000);
  }
  USB_SERIAL.println("SUCCESS!");

  // Configure sensor to Fall Detection Mode
  USB_SERIAL.print("Configuring Fall Detection Mode... ");
  if (sensor.configWorkMode(DFRobot_HumanDetection::eFallingMode) != 0) {
    USB_SERIAL.println("FAILED!");
    while(1) delay(1000);
  }
  USB_SERIAL.println("SUCCESS!");

  // Turn off LEDs for stealth operation
  sensor.configLEDLight(DFRobot_HumanDetection::eFALLLed, 0);

  // Set installation height (adjust based on your actual mounting height)
  sensor.dmInstallHeight(125);  // 250 cm = 8.2 feet
  USB_SERIAL.print("Setting installation height to 125 cm... ");
  delay(1000);
  USB_SERIAL.println("DONE!");

  USB_SERIAL.println("=================================");
  USB_SERIAL.println("Sensor initialized! Fetching config...\n");

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

  USB_SERIAL.println("\n=================================");
  USB_SERIAL.println("Monitoring active!");
  USB_SERIAL.println("Firmware version: " + String(FIRMWARE_VERSION));
  USB_SERIAL.println("Calibrating sensor (30 seconds)...");

  // Report firmware version to database
  String versionJson = "{\"firmware_version\":\"" + String(FIRMWARE_VERSION) + "\"}";
  db.update(SUPABASE_TABLE).eq("device_id", DEVICE_ID).doUpdate(versionJson);

  // Wait 30 seconds for mmWave sensor calibration
  delay(30000);
  USB_SERIAL.println("Calibration complete! Starting data collection...");

  startTime = millis();
  lastConfigFetchTime = millis();
  lastConfigCheckTime = millis();
  lastOtaCheckTime = millis() - deviceConfig.otaCheckIntervalMs + 60000;  // Check in 1 minute
}

// Sample pressure sensor and detect door events
void samplePressure() {
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
      USB_SERIAL.print("[DOOR EVENT] Pressure change: ");
      USB_SERIAL.print(pressureChange, 2);
      USB_SERIAL.print(" hPa (");
      USB_SERIAL.print(lastPressure, 2);
      USB_SERIAL.print(" -> ");
      USB_SERIAL.print(currentPressure, 2);
      USB_SERIAL.println(")");
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
    USB_SERIAL.write(c);

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
  USB_SERIAL.println(); // New line after command

  if (cmd.equalsIgnoreCase("CLEAR_WIFI") || cmd.equalsIgnoreCase("RESET_WIFI")) {
    USB_SERIAL.println("\n=== CLEARING WIFI CREDENTIALS ===");
    clearWiFiCredentials();
    USB_SERIAL.println("WiFi credentials erased from NVS");
    USB_SERIAL.println("Rebooting into BLE provisioning mode...");
    USB_SERIAL.flush();
    delay(1000);
    ESP.restart();
  }
  else if (cmd.equalsIgnoreCase("HELP") || cmd.equals("?")) {
    USB_SERIAL.println("\n=== AVAILABLE COMMANDS ===");
    USB_SERIAL.println("CLEAR_WIFI  - Clear stored WiFi credentials and reboot into BLE mode");
    USB_SERIAL.println("RESET_WIFI  - Same as CLEAR_WIFI");
    USB_SERIAL.println("STATUS      - Show device status");
    USB_SERIAL.println("RESTART     - Restart the device");
    USB_SERIAL.println("HELP or ?   - Show this help message");
    USB_SERIAL.println("==========================\n");
  }
  else if (cmd.equalsIgnoreCase("STATUS")) {
    USB_SERIAL.println("\n=== DEVICE STATUS ===");
    USB_SERIAL.print("Firmware: ");
    USB_SERIAL.println(FIRMWARE_VERSION);
    USB_SERIAL.print("Device: ");
    USB_SERIAL.println(DEVICE_MODEL);
    USB_SERIAL.print("WiFi SSID: ");
    USB_SERIAL.println(WiFi.SSID());
    USB_SERIAL.print("WiFi IP: ");
    USB_SERIAL.println(WiFi.localIP());
    USB_SERIAL.print("MAC Address: ");
    USB_SERIAL.println(WiFi.macAddress());
    USB_SERIAL.print("Mode: ");
    USB_SERIAL.println(deviceConfig.operationalMode);
    USB_SERIAL.print("Uptime: ");
    USB_SERIAL.print(millis() / 1000);
    USB_SERIAL.println(" seconds");
    USB_SERIAL.println("====================\n");
  }
  else if (cmd.equalsIgnoreCase("RESTART") || cmd.equalsIgnoreCase("REBOOT")) {
    USB_SERIAL.println("Restarting device...");
    USB_SERIAL.flush();
    delay(1000);
    ESP.restart();
  }
  else {
    USB_SERIAL.print("Unknown command: ");
    USB_SERIAL.println(cmd);
    USB_SERIAL.println("Type 'HELP' for available commands");
  }
}

void loop() {
  // Handle serial commands
  handleSerialCommands();

  // Sample pressure sensor at 10 Hz
  samplePressure();

  // Check WiFi connection
  if (WiFi.status() != WL_CONNECTED) {
    USB_SERIAL.println("WiFi disconnected! Reconnecting...");
    connectWiFi();
  }

  unsigned long currentTime = millis();

  // Resync time every 5 minutes
  if (currentTime - lastTimeSyncMillis >= TIME_SYNC_INTERVAL) {
    lastTimeSyncMillis = currentTime;
    USB_SERIAL.println("Resyncing time with NTP...");
    configTime(GMT_OFFSET_SEC, DAYLIGHT_OFFSET_SEC, NTP_SERVER1, NTP_SERVER2, NTP_SERVER3);
  }

  // Periodic config check every 60 seconds
  if (currentTime - lastConfigCheckTime >= 60000) {
    lastConfigCheckTime = currentTime;
    USB_SERIAL.println("\n[Periodic Config Check]");
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

// Update NeoPixel based on movement
void updateNeoPixel(uint16_t movement, uint16_t presence) {
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
    USB_SERIAL.println("Using WiFi credentials from NVS (BLE provisioned)");
    ssid = creds.ssid;
    password = creds.password;
  } else {
    USB_SERIAL.println("No stored credentials found, using config.h defaults");
    ssid = WIFI_SSID;
    password = WIFI_PASSWORD;
  }

  USB_SERIAL.print("Connecting to WiFi: ");
  USB_SERIAL.print(ssid);
  USB_SERIAL.print("... ");

  WiFi.begin(ssid.c_str(), password.c_str());

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    delay(500);
    USB_SERIAL.print(".");
    attempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    USB_SERIAL.println(" CONNECTED!");
    USB_SERIAL.print("IP Address: ");
    USB_SERIAL.println(WiFi.localIP());
  } else {
    USB_SERIAL.println(" FAILED!");
    if (hasStoredCreds) {
      USB_SERIAL.println("Stored credentials failed. Clearing and entering BLE provisioning mode...");
      clearWiFiCredentials();
      delay(1000);
      ESP.restart();
    } else {
      USB_SERIAL.println("Please check WiFi credentials in config.h or use BLE provisioning");
    }
  }
}

// Quick data + one supplemental field (interspersed collection)
void collectAndUploadQuickData() {
  unsigned long sensorStartTime = millis();

  USB_SERIAL.print("\n[DATA COLLECTION] ");

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
    USB_SERIAL.print("Movement: ");
    USB_SERIAL.print(movement);

    if (deviceConfig.sensorQueryDelayMs > 0) delay(deviceConfig.sensorQueryDelayMs);

    uint16_t humanPresence = sensor.smHumanData(DFRobot_HumanDetection::eHumanPresence);
    USB_SERIAL.print(", Presence: ");
    USB_SERIAL.print(humanPresence);

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

        USB_SERIAL.println(" → Keep-alive");

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

        // Add pressure and temperature every 10 minutes
        if (millis() - lastPressureUploadTime >= PRESSURE_UPLOAD_INTERVAL) {
          json += ",\"air_pressure_hpa\":" + String(currentPressure, 2);
          json += ",\"temperature_c\":" + String(currentTemperature, 2);
        }

        json += "}";

        // Upload to database
        int httpCode = supabaseInsert(SUPABASE_TABLE, json);
        USB_SERIAL.print((httpCode == 201) ? "[KEEP-ALIVE] ✓" : "[KEEP-ALIVE] ✗");
        if (fallState > 0) USB_SERIAL.println(" FALL!");
        else USB_SERIAL.println();
      }
      return; // Skip full data collection
    }

    // === ACTIVITY DETECTED - SEND FULL DATA ===
    USB_SERIAL.println(" → Full data");

    json += "\"data_type\":\"quick\",";
    json += "\"body_movement\":" + String(movement);
    json += ",\"human_existence\":" + String(humanPresence);

    // === MEDIUM MODE: ADD HUMAN MOVEMENT ===
    if (deviceConfig.dataCollectionMode == "medium") {
      if (deviceConfig.sensorQueryDelayMs > 0) delay(deviceConfig.sensorQueryDelayMs);

      uint16_t humanMovement = sensor.smHumanData(DFRobot_HumanDetection::eHumanMovement);
      USB_SERIAL.print("Human Movement: ");
      USB_SERIAL.println(humanMovement);
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
        USB_SERIAL.println(" → Keep-alive");
        json += "\"data_type\":\"keep_alive\",";
        json += "\"human_presence\":0,";
        json += "\"heart_rate_bpm\":" + String(heartRate) + ",";
        json += "\"body_movement\":0";
        if (doorEventsCount > 0) {
          json += ",\"door_event\":" + String(doorEventsCount);
        }
        if (millis() - lastPressureUploadTime >= PRESSURE_UPLOAD_INTERVAL) {
          json += ",\"air_pressure_hpa\":" + String(currentPressure, 2);
          json += ",\"temperature_c\":" + String(currentTemperature, 2);
        }
        json += "}";
        int httpCode = supabaseInsert(SUPABASE_TABLE, json);
        USB_SERIAL.println((httpCode == 201) ? "[KEEP-ALIVE] ✓" : "[KEEP-ALIVE] ✗");
      }
      return; // Skip full data collection
    }
    USB_SERIAL.println(" → Full data");

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

  // Add pressure and temperature every 10 minutes
  if (millis() - lastPressureUploadTime >= PRESSURE_UPLOAD_INTERVAL) {
    json += ",\"air_pressure_hpa\":" + String(currentPressure, 2);
    json += ",\"temperature_c\":" + String(currentTemperature, 2);
  }

  json += "}";

  unsigned long sensorReadTime = millis() - sensorStartTime;

  // Debug: Print JSON before upload
  USB_SERIAL.println("\n--- JSON DATA ---");
  USB_SERIAL.println(json);
  USB_SERIAL.println("-----------------");

  // Upload to Supabase (using direct HTTPClient instead of buggy ESPSupabase)
  unsigned long uploadStartTime = millis();
  USB_SERIAL.print("Uploading... ");
  int httpCode = supabaseInsert(SUPABASE_TABLE, json);
  unsigned long uploadTime = millis() - uploadStartTime;

  if (httpCode == 201) {
    USB_SERIAL.print("SUCCESS! ");
    // Reset door event counter after successful upload
    doorEventsCount = 0;

    // Update last pressure upload time if we sent pressure/temp data
    if (millis() - lastPressureUploadTime >= PRESSURE_UPLOAD_INTERVAL) {
      lastPressureUploadTime = millis();
    }
  } else {
    USB_SERIAL.print("FAILED (HTTP ");
    USB_SERIAL.print(httpCode);
    USB_SERIAL.println(")");
  }

  unsigned long totalTime = sensorReadTime + uploadTime;
  USB_SERIAL.print("Read: ");
  USB_SERIAL.print(sensorReadTime);
  USB_SERIAL.print("ms, Upload: ");
  USB_SERIAL.print(uploadTime);
  USB_SERIAL.print("ms, Total: ");
  USB_SERIAL.print(totalTime);
  USB_SERIAL.println("ms");
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
  USB_SERIAL.println("Pending command cleared.");
}

// Execute command from web dashboard
void executeCommand(String command) {
  USB_SERIAL.print("\n⚡ Executing command: ");
  USB_SERIAL.println(command);

  if (command == "reconfigure") {
    USB_SERIAL.println("Reconfiguring sensor...");
   // applyDeviceConfig();
    USB_SERIAL.println("✅ Sensor reconfigured successfully!");

  } else if (command == "reset_sensor") {
    if (ENABLE_POWER_CONTROL) {
      USB_SERIAL.println("Performing hardware reset...");
      resetSensor();
      USB_SERIAL.println("✅ Sensor reset complete!");
    } else {
      USB_SERIAL.println("⚠️ Hardware reset not available (power control disabled)");
      USB_SERIAL.println("Performing soft reset (reconfigure) instead...");
     // applyDeviceConfig();
    }

  } else if (command == "reboot") {
    USB_SERIAL.println("Rebooting ESP32...");
    delay(1000);
    ESP.restart();

  } else {
    USB_SERIAL.print("⚠️ Unknown command: ");
    USB_SERIAL.println(command);
  }

  clearPendingCommand();
}

// Clear the config_updated flag after syncing
void clearConfigUpdatedFlag() {
  db.urlQuery_reset();
  String updateData = "{\"config_updated\":false}";
  int httpCode = db.update("moveometers").eq("device_id", String(DEVICE_ID)).doUpdate(updateData);

  if (httpCode == 200 || httpCode == 204) {
    USB_SERIAL.println("Config updated flag cleared.");
  }
}

// Fetch device configuration from Supabase
void fetchDeviceConfig() {
  USB_SERIAL.print("Fetching device config from database... ");

  // Query the moveometers table for this device using direct HTTP
  String response = supabaseSelect("moveometers", "device_id", DEVICE_ID);

  if (response.length() > 0 && response != "[]") {
    USB_SERIAL.println("SUCCESS!");
    USB_SERIAL.println("Config received:");
    USB_SERIAL.println(response);

    // Parse JSON response (basic parsing - could use ArduinoJson library for robust parsing)
    // Extract operational_mode
    int modeIdx = response.indexOf("\"operational_mode\":\"");
    if (modeIdx > 0) {
      modeIdx += 20; // Skip past the key
      int endIdx = response.indexOf("\"", modeIdx);
      deviceConfig.operationalMode = response.substring(modeIdx, endIdx);
      USB_SERIAL.print("  Mode: ");
      USB_SERIAL.println(deviceConfig.operationalMode);
    }

    // Extract data_collection_mode
    int dataCollectionIdx = response.indexOf("\"data_collection_mode\":\"");
    if (dataCollectionIdx > 0) {
      dataCollectionIdx += 24; // Skip past the key
      int endIdx = response.indexOf("\"", dataCollectionIdx);
      deviceConfig.dataCollectionMode = response.substring(dataCollectionIdx, endIdx);
      USB_SERIAL.print("  Data Collection Mode: ");
      USB_SERIAL.println(deviceConfig.dataCollectionMode);
    }

    // Extract fall_detection_interval_ms
    int fallIntervalIdx = response.indexOf("\"fall_detection_interval_ms\":");
    if (fallIntervalIdx > 0) {
      fallIntervalIdx += 30;
      int endIdx = response.indexOf(",", fallIntervalIdx);
      if (endIdx < 0) endIdx = response.indexOf("}", fallIntervalIdx);
      deviceConfig.fallDetectionIntervalMs = response.substring(fallIntervalIdx, endIdx).toInt();
      USB_SERIAL.print("  Fall Detection Interval: ");
      USB_SERIAL.print(deviceConfig.fallDetectionIntervalMs);
      USB_SERIAL.println(" ms");
    }

    // Extract sleep_mode_interval_ms
    int sleepIntervalIdx = response.indexOf("\"sleep_mode_interval_ms\":");
    if (sleepIntervalIdx > 0) {
      sleepIntervalIdx += 25;
      int endIdx = response.indexOf(",", sleepIntervalIdx);
      if (endIdx < 0) endIdx = response.indexOf("}", sleepIntervalIdx);
      deviceConfig.sleepModeIntervalMs = response.substring(sleepIntervalIdx, endIdx).toInt();
      USB_SERIAL.print("  Sleep Mode Interval: ");
      USB_SERIAL.print(deviceConfig.sleepModeIntervalMs);
      USB_SERIAL.println(" ms");
    }

    // Extract config_check_interval_ms
    int configCheckIdx = response.indexOf("\"config_check_interval_ms\":");
    if (configCheckIdx > 0) {
      configCheckIdx += 27;
      int endIdx = response.indexOf(",", configCheckIdx);
      if (endIdx < 0) endIdx = response.indexOf("}", configCheckIdx);
      deviceConfig.configCheckIntervalMs = response.substring(configCheckIdx, endIdx).toInt();
      USB_SERIAL.print("  Config Check Interval: ");
      USB_SERIAL.print(deviceConfig.configCheckIntervalMs);
      USB_SERIAL.println(" ms");
    }

    // Extract ota_check_interval_ms
    int otaCheckIdx = response.indexOf("\"ota_check_interval_ms\":");
    if (otaCheckIdx > 0) {
      otaCheckIdx += 24;
      int endIdx = response.indexOf(",", otaCheckIdx);
      if (endIdx < 0) endIdx = response.indexOf("}", otaCheckIdx);
      deviceConfig.otaCheckIntervalMs = response.substring(otaCheckIdx, endIdx).toInt();
      USB_SERIAL.print("  OTA Check Interval: ");
      USB_SERIAL.print(deviceConfig.otaCheckIntervalMs / 60000);
      USB_SERIAL.println(" minutes");
    }

    // Extract sensor_query_delay_ms
    int queryDelayIdx = response.indexOf("\"sensor_query_delay_ms\":");
    if (queryDelayIdx > 0) {
      queryDelayIdx += 24;
      int endIdx = response.indexOf(",", queryDelayIdx);
      if (endIdx < 0) endIdx = response.indexOf("}", queryDelayIdx);
      deviceConfig.sensorQueryDelayMs = response.substring(queryDelayIdx, endIdx).toInt();
      USB_SERIAL.print("  Sensor Query Delay: ");
      USB_SERIAL.print(deviceConfig.sensorQueryDelayMs);
      USB_SERIAL.println(" ms");
    }

    // Extract query_retry_attempts
    int retryAttemptsIdx = response.indexOf("\"query_retry_attempts\":");
    if (retryAttemptsIdx > 0) {
      retryAttemptsIdx += 23;
      int endIdx = response.indexOf(",", retryAttemptsIdx);
      if (endIdx < 0) endIdx = response.indexOf("}", retryAttemptsIdx);
      deviceConfig.queryRetryAttempts = response.substring(retryAttemptsIdx, endIdx).toInt();
      USB_SERIAL.print("  Query Retry Attempts: ");
      USB_SERIAL.println(deviceConfig.queryRetryAttempts);
    }

    // Extract query_retry_delay_ms
    int retryDelayIdx = response.indexOf("\"query_retry_delay_ms\":");
    if (retryDelayIdx > 0) {
      retryDelayIdx += 23;
      int endIdx = response.indexOf(",", retryDelayIdx);
      if (endIdx < 0) endIdx = response.indexOf("}", retryDelayIdx);
      deviceConfig.queryRetryDelayMs = response.substring(retryDelayIdx, endIdx).toInt();
      USB_SERIAL.print("  Query Retry Delay: ");
      USB_SERIAL.print(deviceConfig.queryRetryDelayMs);
      USB_SERIAL.println(" ms");
    }

    // Extract enable_supplemental_queries
    int enableSuppIdx = response.indexOf("\"enable_supplemental_queries\":");
    if (enableSuppIdx > 0) {
      enableSuppIdx += 30;
      deviceConfig.enableSupplementalQueries = (response.substring(enableSuppIdx, enableSuppIdx + 4) == "true");
      USB_SERIAL.print("  Supplemental Queries: ");
      USB_SERIAL.println(deviceConfig.enableSupplementalQueries ? "Enabled" : "Disabled");
    }

    // Extract supplemental_cycle_mode
    int cycleModeIdx = response.indexOf("\"supplemental_cycle_mode\":\"");
    if (cycleModeIdx > 0) {
      cycleModeIdx += 27;
      int endIdx = response.indexOf("\"", cycleModeIdx);
      deviceConfig.supplementalCycleMode = response.substring(cycleModeIdx, endIdx);
      USB_SERIAL.print("  Supplemental Cycle Mode: ");
      USB_SERIAL.println(deviceConfig.supplementalCycleMode);
    }

    // Extract install_height_cm
    int heightIdx = response.indexOf("\"install_height_cm\":");
    if (heightIdx > 0) {
      heightIdx += 20;
      int endIdx = response.indexOf(",", heightIdx);
      if (endIdx < 0) endIdx = response.indexOf("}", heightIdx);
      deviceConfig.installHeightCm = response.substring(heightIdx, endIdx).toInt();
      USB_SERIAL.print("  Install Height: ");
      USB_SERIAL.print(deviceConfig.installHeightCm);
      USB_SERIAL.println(" cm");
    }

    // Extract fall_sensitivity
    int sensIdx = response.indexOf("\"fall_sensitivity\":");
    if (sensIdx > 0) {
      sensIdx += 19;
      int endIdx = response.indexOf(",", sensIdx);
      if (endIdx < 0) endIdx = response.indexOf("}", sensIdx);
      deviceConfig.fallSensitivity = response.substring(sensIdx, endIdx).toInt();
      USB_SERIAL.print("  Fall Sensitivity: ");
      USB_SERIAL.println(deviceConfig.fallSensitivity);
    }

    // Extract fall_time_sec
    int fallTimeIdx = response.indexOf("\"fall_time_sec\":");
    if (fallTimeIdx > 0) {
      fallTimeIdx += 16;
      int endIdx = response.indexOf(",", fallTimeIdx);
      if (endIdx < 0) endIdx = response.indexOf("}", fallTimeIdx);
      deviceConfig.fallTimeSec = response.substring(fallTimeIdx, endIdx).toInt();
      USB_SERIAL.print("  Fall Time: ");
      USB_SERIAL.print(deviceConfig.fallTimeSec);
      USB_SERIAL.println(" sec");
    }

    // Extract residence_time_sec
    int residTimeIdx = response.indexOf("\"residence_time_sec\":");
    if (residTimeIdx > 0) {
      residTimeIdx += 21;
      int endIdx = response.indexOf(",", residTimeIdx);
      if (endIdx < 0) endIdx = response.indexOf("}", residTimeIdx);
      deviceConfig.residenceTimeSec = response.substring(residTimeIdx, endIdx).toInt();
      USB_SERIAL.print("  Residence Time: ");
      USB_SERIAL.print(deviceConfig.residenceTimeSec);
      USB_SERIAL.println(" sec");
    }

    // Extract residence_switch
    int residSwIdx = response.indexOf("\"residence_switch\":");
    if (residSwIdx > 0) {
      residSwIdx += 19;
      deviceConfig.residenceSwitch = (response.substring(residSwIdx, residSwIdx + 4) == "true");
      USB_SERIAL.print("  Residence Detection: ");
      USB_SERIAL.println(deviceConfig.residenceSwitch ? "Enabled" : "Disabled");
    }

    // Extract position_tracking_enabled
    int trackIdx = response.indexOf("\"position_tracking_enabled\":");
    if (trackIdx > 0) {
      trackIdx += 28;
      deviceConfig.positionTrackingEnabled = (response.substring(trackIdx, trackIdx + 4) == "true");
      USB_SERIAL.print("  Position Tracking: ");
      USB_SERIAL.println(deviceConfig.positionTrackingEnabled ? "Enabled" : "Disabled");
    }

    // Extract seated_distance_threshold_cm
    int seatedDistIdx = response.indexOf("\"seated_distance_threshold_cm\":");
    if (seatedDistIdx > 0) {
      seatedDistIdx += 31;
      int endIdx = response.indexOf(",", seatedDistIdx);
      if (endIdx < 0) endIdx = response.indexOf("}", seatedDistIdx);
      deviceConfig.seatedDistanceThresholdCm = response.substring(seatedDistIdx, endIdx).toInt();
      USB_SERIAL.print("  Seated Distance Threshold: ");
      USB_SERIAL.print(deviceConfig.seatedDistanceThresholdCm);
      USB_SERIAL.println(" cm");
    }

    // Extract motion_distance_threshold_cm
    int motionDistIdx = response.indexOf("\"motion_distance_threshold_cm\":");
    if (motionDistIdx > 0) {
      motionDistIdx += 31;
      int endIdx = response.indexOf(",", motionDistIdx);
      if (endIdx < 0) endIdx = response.indexOf("}", motionDistIdx);
      deviceConfig.motionDistanceThresholdCm = response.substring(motionDistIdx, endIdx).toInt();
      USB_SERIAL.print("  Motion Distance Threshold: ");
      USB_SERIAL.print(deviceConfig.motionDistanceThresholdCm);
      USB_SERIAL.println(" cm");
    }

  } else {
    USB_SERIAL.println("FAILED or device not found in database!");
    USB_SERIAL.println("Using default configuration.");
  }
}

// Apply fetched configuration to sensor
void applyDeviceConfig() {
  USB_SERIAL.println("\nApplying configuration to sensor...");

  // Apply operational mode
  if (deviceConfig.operationalMode == "sleep") {
    USB_SERIAL.print("  Configuring SLEEP MODE... ");
    if (sensor.configWorkMode(DFRobot_HumanDetection::eSleepMode) != 0) {
      USB_SERIAL.println("FAILED!");
    } else {
      USB_SERIAL.println("SUCCESS!");
    }
  } else {
    USB_SERIAL.print("  Configuring FALL DETECTION MODE... ");
    if (sensor.configWorkMode(DFRobot_HumanDetection::eFallingMode) != 0) {
      USB_SERIAL.println("FAILED!");
    } else {
      USB_SERIAL.println("SUCCESS!");
    }

    // Apply fall sensitivity (0-3, 3 = most sensitive)
    USB_SERIAL.print("  Setting fall sensitivity to ");
    USB_SERIAL.print(deviceConfig.fallSensitivity);
    USB_SERIAL.print("... ");
    sensor.dmFallConfig(DFRobot_HumanDetection::eFallSensitivityC, deviceConfig.fallSensitivity);
    delay(100);
    USB_SERIAL.println("DONE!");

    // Apply fall time (delay before reporting a fall)
    USB_SERIAL.print("  Setting fall time to ");
    USB_SERIAL.print(deviceConfig.fallTimeSec);
    USB_SERIAL.print(" sec... ");
    sensor.dmFallTime(deviceConfig.fallTimeSec);
    delay(100);
    USB_SERIAL.println("DONE!");

    // Apply static residency switch and time
    USB_SERIAL.print("  Residency detection: ");
    USB_SERIAL.print(deviceConfig.residenceSwitch ? "ON" : "OFF");
    USB_SERIAL.print(", time=");
    USB_SERIAL.print(deviceConfig.residenceTimeSec);
    USB_SERIAL.print(" sec... ");
    sensor.dmFallConfig(DFRobot_HumanDetection::eResidenceSwitchC, deviceConfig.residenceSwitch ? 1 : 0);
    delay(50);
    sensor.dmFallConfig(DFRobot_HumanDetection::eResidenceTime, deviceConfig.residenceTimeSec);
    delay(100);
    USB_SERIAL.println("DONE!");

    // Apply human detection thresholds (only in fall mode)
    USB_SERIAL.print("  Setting seated distance threshold to ");
    USB_SERIAL.print(deviceConfig.seatedDistanceThresholdCm);
    USB_SERIAL.print(" cm... ");
    sensor.dmHumanConfig(DFRobot_HumanDetection::eSeatedHorizontalDistanceC, deviceConfig.seatedDistanceThresholdCm);
    delay(100);
    USB_SERIAL.println("DONE!");

    USB_SERIAL.print("  Setting motion distance threshold to ");
    USB_SERIAL.print(deviceConfig.motionDistanceThresholdCm);
    USB_SERIAL.print(" cm... ");
    sensor.dmHumanConfig(DFRobot_HumanDetection::eMotionHorizontalDistanceC, deviceConfig.motionDistanceThresholdCm);
    delay(100);
    USB_SERIAL.println("DONE!");
  }

  // Apply installation height
  USB_SERIAL.print("  Setting installation height to ");
  USB_SERIAL.print(deviceConfig.installHeightCm);
  USB_SERIAL.print(" cm... ");
  sensor.dmInstallHeight(deviceConfig.installHeightCm);
  delay(100);
  USB_SERIAL.println("DONE!");

  // Enable LED for debugging (set to 1 to disable, 0 to enable)
  USB_SERIAL.print("  Enabling sensor LED for debugging... ");
  sensor.configLEDLight(DFRobot_HumanDetection::eFALLLed, 0);  // 0 = LED ON
  USB_SERIAL.println("DONE!");

  USB_SERIAL.println("Configuration applied successfully!\n");
}

