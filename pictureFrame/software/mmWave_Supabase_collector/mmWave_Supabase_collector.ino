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
 */

#include <WiFi.h>
#include <ESPSupabase.h>
#include <time.h>
#include "DFRobot_HumanDetection.h"
#include "config.h"

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
  int dataIntervalMs = 1000;
  int installHeightCm = 250;
  int fallSensitivity = 5;
  int installAngle = 0;
  bool positionTrackingEnabled = true;
  int seatedDistanceThresholdCm = 100;  // Seated horizontal distance threshold
  int motionDistanceThresholdCm = 150;  // Motion horizontal distance threshold
} deviceConfig;

unsigned long lastQuickDataTime = 0;
unsigned long lastFullDataTime = 0;
unsigned long lastConfigFetchTime = 0;
unsigned long startTime = 0;
int uploadFailCount = 0;

// Data collection intervals
#define QUICK_DATA_INTERVAL 1000   // 1 second for position/fall state
#define FULL_DATA_INTERVAL 10000   // 10 seconds for complete data
#define CONFIG_FETCH_INTERVAL 600000  // 10 minutes

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
  USB_SERIAL.println("Calibrating sensor (wait 30-60 seconds)...");

  startTime = millis();
  lastConfigFetchTime = millis();
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

  // Fetch updated configuration every 10 minutes
  if (currentTime - lastConfigFetchTime >= CONFIG_FETCH_INTERVAL) {
    lastConfigFetchTime = currentTime;
    USB_SERIAL.println("Checking for configuration updates...");
    fetchDeviceConfig();
    applyDeviceConfig();
  }

  // Quick data collection (position + fall state) every 1 second
  if (currentTime - lastQuickDataTime >= QUICK_DATA_INTERVAL) {
    lastQuickDataTime = currentTime;
    collectAndUploadQuickData();
  }

  // Full data collection every 10 seconds
  if (currentTime - lastFullDataTime >= FULL_DATA_INTERVAL) {
    lastFullDataTime = currentTime;
    collectAndUploadFullData();
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

// Quick data collection - position and fall state only (fast!)
void collectAndUploadQuickData() {
  USB_SERIAL.println("\n[QUICK] Reading position/fall...");

  unsigned long sensorStartTime = millis();

  // Build minimal JSON with only critical data
  String json = "{";
  json += "\"device_id\":\"" + String(DEVICE_ID) + "\",";
  json += "\"location\":\"" + String(LOCATION) + "\",";
  json += "\"sensor_mode\":\"" + deviceConfig.operationalMode + "\",";
  json += "\"device_timestamp\":\"" + getISOTimestamp() + "\",";
  json += "\"uptime_sec\":" + String((millis() - startTime) / 1000) + ",";
  json += "\"data_type\":\"quick\",";

  if (deviceConfig.operationalMode == "fall_detection") {
    // Critical fall detection data
    uint16_t existence = sensor.dmHumanData(DFRobot_HumanDetection::eExistence);
    uint16_t motion = sensor.dmHumanData(DFRobot_HumanDetection::eMotion);
    uint16_t fallState = sensor.getFallData(DFRobot_HumanDetection::eFallState);
    uint16_t staticResidency = sensor.getFallData(DFRobot_HumanDetection::estaticResidencyState);

    json += "\"human_existence\":" + String(existence) + ",";
    json += "\"motion_detected\":" + String(motion) + ",";
    json += "\"fall_state\":" + String(fallState) + ",";
    json += "\"static_residency\":" + String(staticResidency) + ",";

    // Position tracking
    uint16_t trackX = 0;
    uint16_t trackY = 0;
    sensor.track(&trackX, &trackY);

    json += "\"track_x\":" + String(trackX) + ",";
    json += "\"track_y\":" + String(trackY);
  } else {
    // Sleep mode - just presence
    uint16_t humanPresence = sensor.smHumanData(DFRobot_HumanDetection::eHumanPresence);
    uint8_t heartRate = sensor.getHeartRate();

    json += "\"human_presence\":" + String(humanPresence) + ",";
    json += "\"heart_rate_bpm\":" + String(heartRate);
  }

  json += "}";

  unsigned long sensorReadTime = millis() - sensorStartTime;

  // Debug: Print JSON
  USB_SERIAL.println("\n[QUICK] JSON:");
  USB_SERIAL.println(json);

  // Upload
  unsigned long uploadStartTime = millis();
  USB_SERIAL.print("[QUICK] Uploading... ");
  int httpCode = db.insert(SUPABASE_TABLE, json, false);
  unsigned long uploadTime = millis() - uploadStartTime;

  if (httpCode == 201) {
    USB_SERIAL.print("SUCCESS! ");
  } else {
    USB_SERIAL.print("FAILED (HTTP ");
    USB_SERIAL.print(httpCode);
    USB_SERIAL.println(")");

    // Print response body for debugging
    if (httpCode > 0) {
      USB_SERIAL.println("Response: (check Supabase logs for details)");
    }
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

// Full data collection - all sensor data (slow)
void collectAndUploadFullData() {
  // Add debug info before building JSON
  USB_SERIAL.println("\n========== [FULL] SENSOR READ ==========");

  // Measure sensor data collection time
  unsigned long sensorStartTime = millis();
  USB_SERIAL.print("[FULL] Reading all sensor data... ");

  // Build JSON string with all sensor data
  String jsonData = buildSensorJSON();

  unsigned long sensorEndTime = millis();
  unsigned long sensorReadTime = sensorEndTime - sensorStartTime;

  // Print timing and data
  USB_SERIAL.print("DONE (");
  USB_SERIAL.print(sensorReadTime);
  USB_SERIAL.println(" ms)");
  USB_SERIAL.println("Data collected:");
  USB_SERIAL.println(jsonData);
  USB_SERIAL.print("Sensor read time: ");
  USB_SERIAL.print(sensorReadTime);
  USB_SERIAL.println(" ms");
  USB_SERIAL.println("=================================");

  // Upload to Supabase with retry logic
  unsigned long uploadStartTime = millis();
  bool uploadSuccess = false;
  for (int attempt = 0; attempt < RETRY_ATTEMPTS && !uploadSuccess; attempt++) {
    if (attempt > 0) {
      USB_SERIAL.print("Retry attempt ");
      USB_SERIAL.print(attempt);
      USB_SERIAL.println("...");
      delay(RETRY_DELAY);
    }

    USB_SERIAL.print("Uploading to Supabase... ");
    unsigned long uploadAttemptStart = millis();
    int httpCode = db.insert(SUPABASE_TABLE, jsonData, false);
    unsigned long uploadAttemptTime = millis() - uploadAttemptStart;

    if (httpCode == 201) {
      USB_SERIAL.print("SUCCESS! (");
      USB_SERIAL.print(uploadAttemptTime);
      USB_SERIAL.println(" ms)");
      uploadSuccess = true;
      uploadFailCount = 0;
    } else {
      USB_SERIAL.print("FAILED! HTTP Code: ");
      USB_SERIAL.print(httpCode);
      USB_SERIAL.print(" (");
      USB_SERIAL.print(uploadAttemptTime);
      USB_SERIAL.println(" ms)");
      uploadFailCount++;
    }
  }

  unsigned long uploadEndTime = millis();
  unsigned long totalUploadTime = uploadEndTime - uploadStartTime;

  if (!uploadSuccess) {
    USB_SERIAL.print("Upload failed after ");
    USB_SERIAL.print(RETRY_ATTEMPTS);
    USB_SERIAL.println(" attempts.");
    USB_SERIAL.print("Total consecutive failures: ");
    USB_SERIAL.println(uploadFailCount);
  }

  // Print timing summary
  unsigned long totalTime = sensorReadTime + totalUploadTime;
  USB_SERIAL.println("\n--- Timing Summary ---");
  USB_SERIAL.print("Sensor read:  ");
  USB_SERIAL.print(sensorReadTime);
  USB_SERIAL.println(" ms");
  USB_SERIAL.print("Upload:       ");
  USB_SERIAL.print(totalUploadTime);
  USB_SERIAL.println(" ms");
  USB_SERIAL.print("TOTAL:        ");
  USB_SERIAL.print(totalTime);
  USB_SERIAL.println(" ms");
  USB_SERIAL.print("Data interval: ");
  USB_SERIAL.print(deviceConfig.dataIntervalMs);
  USB_SERIAL.println(" ms");

  if (totalTime > deviceConfig.dataIntervalMs) {
    USB_SERIAL.print("WARNING: Total time (");
    USB_SERIAL.print(totalTime);
    USB_SERIAL.print(" ms) exceeds data interval (");
    USB_SERIAL.print(deviceConfig.dataIntervalMs);
    USB_SERIAL.println(" ms)!");
  }
  USB_SERIAL.println();
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

    // Extract data_interval_ms
    int intervalIdx = response.indexOf("\"data_interval_ms\":");
    if (intervalIdx > 0) {
      intervalIdx += 19;
      int endIdx = response.indexOf(",", intervalIdx);
      if (endIdx < 0) endIdx = response.indexOf("}", intervalIdx);
      deviceConfig.dataIntervalMs = response.substring(intervalIdx, endIdx).toInt();
      USB_SERIAL.print("  Data Interval: ");
      USB_SERIAL.print(deviceConfig.dataIntervalMs);
      USB_SERIAL.println(" ms");
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

  // Turn off LEDs for stealth operation
  sensor.configLEDLight(DFRobot_HumanDetection::eFALLLed, 1);

  USB_SERIAL.println("Configuration applied successfully!\n");
}

String buildSensorJSON() {
  String json = "{";

  // Metadata with accurate device timestamp
  json += "\"device_id\":\"" + String(DEVICE_ID) + "\",";
  json += "\"location\":\"" + String(LOCATION) + "\",";
  json += "\"sensor_mode\":\"" + deviceConfig.operationalMode + "\",";
  json += "\"device_timestamp\":\"" + getISOTimestamp() + "\",";
  json += "\"data_type\":\"full\",";
  json += "\"uptime_sec\":" + String((millis() - startTime) / 1000) + ",";

  // Collect data based on operational mode
  if (deviceConfig.operationalMode == "sleep") {
    // --- SLEEP MODE DATA ---

    // Human Presence
    uint16_t humanPresence = sensor.smHumanData(DFRobot_HumanDetection::eHumanPresence);
    uint16_t humanMovement = sensor.smHumanData(DFRobot_HumanDetection::eHumanMovement);
    uint16_t humanMovingRange = sensor.smHumanData(DFRobot_HumanDetection::eHumanMovingRange);

    json += "\"human_presence\":" + String(humanPresence) + ",";
    json += "\"human_movement\":" + String(humanMovement) + ",";
    json += "\"human_move\":" + String(humanMovingRange) + ",";

    // Sleep State
    uint16_t inOrNotInBed = sensor.smSleepData(DFRobot_HumanDetection::eInOrNotInBed);
    uint16_t sleepState = sensor.smSleepData(DFRobot_HumanDetection::eSleepState);

    json += "\"sleep_state\":" + String(sleepState) + ",";
    json += "\"in_bed\":" + String(inOrNotInBed) + ",";

    // Vital Signs
    uint8_t heartRate = sensor.getHeartRate();
    uint8_t respiration = sensor.getBreatheValue();

    json += "\"heart_rate_bpm\":" + String(heartRate) + ",";
    json += "\"respiration_rate\":" + String(respiration) + ",";

    // Sleep Composite Data
    sSleepComposite composite = sensor.getSleepComposite();
    json += "\"composite_presence\":" + String(composite.presence) + ",";
    json += "\"composite_sleep_state\":" + String(composite.sleepState) + ",";
    json += "\"composite_avg_respiration\":" + String(composite.averageRespiration) + ",";
    json += "\"composite_avg_heartbeat\":" + String(composite.averageHeartbeat) + ",";
    json += "\"composite_turn_over_count\":" + String(composite.turnoverNumber) + ",";
    json += "\"stats_large_body_movement\":" + String(composite.largeBodyMove) + ",";
    json += "\"stats_minor_body_movement\":" + String(composite.minorBodyMove) + ",";
    json += "\"composite_apnea_events\":" + String(composite.apneaEvents) + ",";

    // Sleep Statistics
    sSleepStatistics stats = sensor.getSleepStatistics();
    json += "\"stats_sleep_quality_score\":" + String(stats.sleepQualityScore) + ",";
    json += "\"stats_sleep_time_min\":" + String(stats.sleepTime) + ",";
    json += "\"stats_wake_duration\":" + String(stats.wakeDuration) + ",";
    json += "\"stats_light_sleep_pct\":" + String(stats.shallowSleepPercentage) + ",";
    json += "\"stats_deep_sleep_pct\":" + String(stats.deepSleepPercentage) + ",";

    // Abnormal States
    uint16_t abnormalStruggle = sensor.smSleepData(DFRobot_HumanDetection::eAbnormalStruggle);
    uint16_t unattendedState = sensor.smSleepData(DFRobot_HumanDetection::eUnattendedState);

    json += "\"abnormal_struggle\":" + String(abnormalStruggle) + ",";
    json += "\"unattended_state\":" + String(unattendedState);

  } else {
    // --- FALL DETECTION MODE DATA ---

    // Human Detection
    uint16_t existence = sensor.dmHumanData(DFRobot_HumanDetection::eExistence);
    uint16_t motion = sensor.dmHumanData(DFRobot_HumanDetection::eMotion);
    uint16_t bodyMove = sensor.dmHumanData(DFRobot_HumanDetection::eBodyMove);
    uint16_t seatedDistance = sensor.dmHumanData(DFRobot_HumanDetection::eSeatedHorizontalDistance);
    uint16_t motionDistance = sensor.dmHumanData(DFRobot_HumanDetection::eMotionHorizontalDistance);

    json += "\"human_existence\":" + String(existence) + ",";
    json += "\"motion_detected\":" + String(motion) + ",";
    json += "\"body_movement\":" + String(bodyMove) + ",";
    json += "\"seated_distance_cm\":" + String(seatedDistance) + ",";
    json += "\"motion_distance_cm\":" + String(motionDistance) + ",";

    // Fall Detection
    uint16_t fallState = sensor.getFallData(DFRobot_HumanDetection::eFallState);
    uint16_t fallBreakHeight = sensor.getFallData(DFRobot_HumanDetection::eFallBreakHeight);
    uint16_t staticResidency = sensor.getFallData(DFRobot_HumanDetection::estaticResidencyState);
    uint16_t fallSensitivity = sensor.getFallData(DFRobot_HumanDetection::eFallSensitivity);

    json += "\"fall_state\":" + String(fallState) + ",";
    json += "\"fall_break_height_cm\":" + String(fallBreakHeight) + ",";
    json += "\"static_residency\":" + String(staticResidency) + ",";
    json += "\"fall_sensitivity\":" + String(fallSensitivity) + ",";

    // Fall Timing
    uint32_t fallTime = sensor.getFallTime();
    uint32_t residencyTime = sensor.getStaticResidencyTime();

    json += "\"fall_time_sec\":" + String(fallTime) + ",";
    json += "\"static_residency_time_sec\":" + String(residencyTime) + ",";

    // Trajectory Tracking (X, Y coordinates)
    uint16_t trackX = 0;
    uint16_t trackY = 0;
    sensor.track(&trackX, &trackY);

    json += "\"track_x\":" + String(trackX) + ",";
    json += "\"track_y\":" + String(trackY);
  }

  json += "}";

  return json;
}
