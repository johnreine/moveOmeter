/*
 * mmWave Fall Detection Data Collector for ESP32-C6
 *
 * Collects fall detection data from DF Robot SEN0623 (C1001 mmWave sensor)
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
#include "DFRobot_HumanDetection.h"
#include "config.h"

// Serial port definitions
#define USB_SERIAL Serial
#define MMWAVE_SERIAL Serial1

// UART pins for ESP32-C6 Feather
#define MMWAVE_RX_PIN 17
#define MMWAVE_TX_PIN 16

// Create sensor and database objects
DFRobot_HumanDetection sensor(&MMWAVE_SERIAL);
Supabase db;

unsigned long lastDataTime = 0;
unsigned long startTime = 0;
int uploadFailCount = 0;

void setup() {
  USB_SERIAL.begin(115200);
  delay(2000);

  USB_SERIAL.println("\n=================================");
  USB_SERIAL.println("mmWave Fall Detection Collector");
  USB_SERIAL.println("=================================");

  // Connect to WiFi
  connectWiFi();

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

  USB_SERIAL.println("=================================");
  USB_SERIAL.println("System ready! Monitoring for falls...\n");

  startTime = millis();
}

void loop() {
  // Check WiFi connection
  if (WiFi.status() != WL_CONNECTED) {
    USB_SERIAL.println("WiFi disconnected! Reconnecting...");
    connectWiFi();
  }

  unsigned long currentTime = millis();

  // Collect and upload data at specified interval
  if (currentTime - lastDataTime >= DATA_INTERVAL) {
    lastDataTime = currentTime;
    collectAndUploadData();
  }
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

void collectAndUploadData() {
  // Build JSON string with all sensor data
  String jsonData = buildSensorJSON();

  // Print JSON to serial for debugging
  USB_SERIAL.println("Data collected:");
  USB_SERIAL.println(jsonData);

  // Upload to Supabase with retry logic
  bool uploadSuccess = false;
  for (int attempt = 0; attempt < RETRY_ATTEMPTS && !uploadSuccess; attempt++) {
    if (attempt > 0) {
      USB_SERIAL.print("Retry attempt ");
      USB_SERIAL.print(attempt);
      USB_SERIAL.println("...");
      delay(RETRY_DELAY);
    }

    USB_SERIAL.print("Uploading to Supabase... ");
    int httpCode = db.insert(SUPABASE_TABLE, jsonData, false);

    if (httpCode == 201) {
      USB_SERIAL.println("SUCCESS!");
      uploadSuccess = true;
      uploadFailCount = 0;
    } else {
      USB_SERIAL.print("FAILED! HTTP Code: ");
      USB_SERIAL.println(httpCode);
      uploadFailCount++;
    }
  }

  if (!uploadSuccess) {
    USB_SERIAL.print("Upload failed after ");
    USB_SERIAL.print(RETRY_ATTEMPTS);
    USB_SERIAL.println(" attempts.");
    USB_SERIAL.print("Total consecutive failures: ");
    USB_SERIAL.println(uploadFailCount);
  }

  USB_SERIAL.println();
}

String buildSensorJSON() {
  String json = "{";

  // Metadata
  json += "\"device_id\":\"" + String(DEVICE_ID) + "\",";
  json += "\"location\":\"" + String(LOCATION) + "\",";
  json += "\"sensor_mode\":\"fall_detection\",";
  json += "\"uptime_sec\":" + String((millis() - startTime) / 1000) + ",";

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

  // Installation Parameters
  uint16_t installHeight = sensor.dmGetInstallHeight();
  json += "\"install_height_cm\":" + String(installHeight) + ",";

  // Trajectory Tracking (X, Y coordinates)
  uint16_t trackX = 0;
  uint16_t trackY = 0;
  sensor.track(&trackX, &trackY);

  json += "\"track_x\":" + String(trackX) + ",";
  json += "\"track_y\":" + String(trackY) + ",";

  // Track Frequency
  uint32_t trackFreq = sensor.trackFrequency();
  json += "\"track_frequency_hz\":" + String(trackFreq);

  json += "}";

  return json;
}
