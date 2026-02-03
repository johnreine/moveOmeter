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
 */

#include <WiFi.h>
#include <ESPSupabase.h>
#include <HTTPUpdate.h>
#include <WiFiClientSecure.h>
#include <time.h>
#include "DFRobot_HumanDetection.h"
#include "config.h"

// Firmware version (update this with each release)
#define FIRMWARE_VERSION "1.0.0"
#define DEVICE_MODEL "ESP32C6_MOVEOMETER"

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

// Create sensor and database objects
DFRobot_HumanDetection sensor(&MMWAVE_SERIAL);
Supabase db;

// Device configuration (fetched from database)
struct DeviceConfig {
  String operationalMode = "fall_detection";  // "fall_detection" or "sleep"
  int fallDetectionIntervalMs = 20000;  // Sampling rate for fall detection mode
  int sleepModeIntervalMs = 20000;      // Sampling rate for sleep mode
  int configCheckIntervalMs = 20000;    // How often to check for config updates
  int otaCheckIntervalMs = 3600000;     // How often to check for firmware updates
  int installHeightCm = 250;
  int fallSensitivity = 5;
  int installAngle = 0;
  bool positionTrackingEnabled = true;
  int seatedDistanceThresholdCm = 100;  // Seated horizontal distance threshold
  int motionDistanceThresholdCm = 150;  // Motion horizontal distance threshold
} deviceConfig;

unsigned long lastQuickDataTime = 0;
unsigned long lastConfigFetchTime = 0;
unsigned long lastConfigCheckTime = 0;
unsigned long lastOtaCheckTime = 0;
unsigned long startTime = 0;
int uploadFailCount = 0;
int supplementalQueryIndex = 0;  // Cycles through additional queries

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
  sensor.dmInstallHeight(250);
  USB_SERIAL.println("Installation height restored to 250cm");

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
  sensor.configLEDLight(DFRobot_HumanDetection::eFALLLed, 1);

  // Set installation height (adjust based on your actual mounting height)
  sensor.dmInstallHeight(250);  // 250 cm = 8.2 feet
  USB_SERIAL.print("Setting installation height to 250 cm... ");
  delay(1000);
  USB_SERIAL.println("DONE!");

  USB_SERIAL.println("=================================");
  USB_SERIAL.println("Sensor initialized! Fetching config...\n");

  // Fetch device configuration from database
  fetchDeviceConfig();

  // Apply configuration based on fetched settings
  applyDeviceConfig();

  USB_SERIAL.println("\n=================================");
  USB_SERIAL.println("Monitoring active!");
  USB_SERIAL.println("Firmware version: " + String(FIRMWARE_VERSION));
  USB_SERIAL.println("Calibrating sensor (wait 30-60 seconds)...");

  // Report firmware version to database
  String versionJson = "{\"firmware_version\":\"" + String(FIRMWARE_VERSION) + "\"}";
  db.update(SUPABASE_TABLE).eq("device_id", DEVICE_ID).doUpdate(versionJson);

  startTime = millis();
  lastConfigFetchTime = millis();
  lastOtaCheckTime = millis() - deviceConfig.otaCheckIntervalMs + 60000;  // Check in 1 minute
}

void loop() {
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

  // Check for immediate config updates and commands (uses configurable interval)
  if (currentTime - lastConfigCheckTime >= deviceConfig.configCheckIntervalMs) {
    lastConfigCheckTime = currentTime;

    // Check for pending commands first
    String command = checkPendingCommand();
    if (command.length() > 0) {
      executeCommand(command);
    }

    // Then check for config updates
    if (checkConfigUpdated()) {
      USB_SERIAL.println("\n🔄 Config update detected! Syncing now...");
      fetchDeviceConfig();
      applyDeviceConfig();
      clearConfigUpdatedFlag();
      lastConfigFetchTime = currentTime;  // Reset periodic timer
    }
  }

  // Fetch updated configuration every 10 minutes (periodic backup)
  if (currentTime - lastConfigFetchTime >= CONFIG_FETCH_INTERVAL) {
    lastConfigFetchTime = currentTime;
    USB_SERIAL.println("Periodic configuration check...");
    fetchDeviceConfig();
    applyDeviceConfig();
  }

  // Check for firmware updates (uses configurable interval)
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

void connectWiFi() {
  USB_SERIAL.print("Connecting to WiFi: ");
  USB_SERIAL.print(WIFI_SSID);
  USB_SERIAL.print("... ");

  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

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
    USB_SERIAL.println("Please check WiFi credentials in config.h");
  }
}

// Quick data + one supplemental field (interspersed collection)
void collectAndUploadQuickData() {
  USB_SERIAL.print("\n[QUICK+SUPP");
  USB_SERIAL.print(supplementalQueryIndex);
  USB_SERIAL.println("] Reading...");

  unsigned long sensorStartTime = millis();

  // Build JSON with critical data
  String json = "{";
  json += "\"device_id\":\"" + String(DEVICE_ID) + "\",";
  json += "\"location\":\"" + String(LOCATION) + "\",";
  json += "\"sensor_mode\":\"" + deviceConfig.operationalMode + "\",";
  json += "\"device_timestamp\":\"" + getISOTimestamp() + "\",";
  json += "\"uptime_sec\":" + String((millis() - startTime) / 1000) + ",";
  json += "\"data_type\":\"quick\",";

  if (deviceConfig.operationalMode == "fall_detection") {
    // === CRITICAL DATA (every read) ===
    uint16_t existence = sensor.dmHumanData(DFRobot_HumanDetection::eExistence);
    uint16_t motion = sensor.dmHumanData(DFRobot_HumanDetection::eMotion);
    uint16_t bodyMove = sensor.dmHumanData(DFRobot_HumanDetection::eBodyMove);
    uint16_t fallState = sensor.getFallData(DFRobot_HumanDetection::eFallState);

    json += "\"human_existence\":" + String(existence) + ",";
    json += "\"motion_detected\":" + String(motion) + ",";
    json += "\"body_movement\":" + String(bodyMove) + ",";
    json += "\"fall_state\":" + String(fallState);

    // === SUPPLEMENTAL DATA (one per cycle) ===
    // Cycle through 7 additional queries over 7 seconds
    switch (supplementalQueryIndex) {
      case 0: {
        uint16_t staticResidency = sensor.getFallData(DFRobot_HumanDetection::estaticResidencyState);
        json += ",\"static_residency\":" + String(staticResidency);
        break;
      }
      case 1: {
        uint16_t seatedDistance = sensor.dmHumanData(DFRobot_HumanDetection::eSeatedHorizontalDistance);
        json += ",\"seated_distance_cm\":" + String(seatedDistance);
        break;
      }
      case 2: {
        uint16_t motionDistance = sensor.dmHumanData(DFRobot_HumanDetection::eMotionHorizontalDistance);
        json += ",\"motion_distance_cm\":" + String(motionDistance);
        break;
      }
      case 3: {
        uint16_t fallBreakHeight = sensor.getFallData(DFRobot_HumanDetection::eFallBreakHeight);
        json += ",\"fall_break_height_cm\":" + String(fallBreakHeight);
        break;
      }
      case 4: {
        uint32_t fallTime = sensor.getFallTime();
        json += ",\"fall_time_sec\":" + String(fallTime);
        break;
      }
      case 5: {
        uint32_t residencyTime = sensor.getStaticResidencyTime();
        json += ",\"static_residency_time_sec\":" + String(residencyTime);
        break;
      }
      case 6: {
        // No additional query this cycle - just critical data
        break;
      }
    }

    // Increment and wrap supplemental query index (7 cycles total, 0-6)
    supplementalQueryIndex = (supplementalQueryIndex + 1) % 7;

  } else {
    // === SLEEP MODE ===
    // Critical data - collected every cycle
    uint16_t humanPresence = sensor.smHumanData(DFRobot_HumanDetection::eHumanPresence);
    uint8_t heartRate = sensor.getHeartRate();
    uint16_t bodyMovement = sensor.smHumanData(DFRobot_HumanDetection::eHumanMovement);

    json += "\"human_presence\":" + String(humanPresence) + ",";
    json += "\"heart_rate_bpm\":" + String(heartRate) + ",";
    json += "\"body_movement\":" + String(bodyMovement);

    // Supplemental queries for sleep mode (now 10 fields, removed humanMovement since it's in critical data)
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

    // Increment and wrap for sleep mode (10 supplemental cycles)
    supplementalQueryIndex = (supplementalQueryIndex + 1) % 10;
  }

  json += "}";

  unsigned long sensorReadTime = millis() - sensorStartTime;

  // Debug: Print JSON before upload
  USB_SERIAL.println("\n--- JSON DATA ---");
  USB_SERIAL.println(json);
  USB_SERIAL.println("-----------------");

  // Upload to Supabase
  unsigned long uploadStartTime = millis();
  USB_SERIAL.print("Uploading... ");
  int httpCode = db.insert(SUPABASE_TABLE, json, false);
  unsigned long uploadTime = millis() - uploadStartTime;

  if (httpCode == 201) {
    USB_SERIAL.print("SUCCESS! ");
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
    applyDeviceConfig();
    USB_SERIAL.println("✅ Sensor reconfigured successfully!");

  } else if (command == "reset_sensor") {
    if (ENABLE_POWER_CONTROL) {
      USB_SERIAL.println("Performing hardware reset...");
      resetSensor();
      USB_SERIAL.println("✅ Sensor reset complete!");
    } else {
      USB_SERIAL.println("⚠️ Hardware reset not available (power control disabled)");
      USB_SERIAL.println("Performing soft reset (reconfigure) instead...");
      applyDeviceConfig();
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

  // Query the moveometers table for this device using builder pattern
  db.urlQuery_reset();
  String response = db.from("moveometers").select("*").eq("device_id", String(DEVICE_ID)).doSelect();

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

    // Apply fall sensitivity (only in fall mode)
    USB_SERIAL.print("  Setting fall sensitivity to ");
    USB_SERIAL.print(deviceConfig.fallSensitivity);
    USB_SERIAL.print("... ");
    sensor.dmFallConfig(DFRobot_HumanDetection::eFallSensitivityC, deviceConfig.fallSensitivity);
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

