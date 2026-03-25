/*
 * BLE Provisioning Implementation
 */

#include <WiFi.h>
#include "ble_provisioning.h"

// Global state
bool bleProvisioningActive = false;
BLEServer* pServer = nullptr;
bool deviceConnected = false;
bool credentialsReceived = false;
bool credentialsPending = false;
String pendingCredentialsJSON = "";
BLECharacteristic* pCredentialCharacteristic = nullptr;

// Generate BLE device name from MAC address
String getBLEDeviceName() {
  uint8_t mac[6];
  WiFi.macAddress(mac);
  char name[32];
  snprintf(name, sizeof(name), "moveOmeter-%02X%02X%02X",
           mac[3], mac[4], mac[5]);
  return String(name);
}

// Load WiFi credentials from NVS
bool loadWiFiCredentials(WiFiCredentials& creds) {
  Preferences preferences;
  preferences.begin(WIFI_NVS_NAMESPACE, true); // read-only

  creds.ssid = preferences.getString("ssid", "");
  creds.password = preferences.getString("password", "");
  preferences.end();

  creds.isValid = (creds.ssid.length() > 0);
  return creds.isValid;
}

// Save WiFi credentials to NVS
void saveWiFiCredentials(const String& ssid, const String& password) {
  Preferences preferences;
  preferences.begin(WIFI_NVS_NAMESPACE, false); // read-write

  preferences.putString("ssid", ssid);
  preferences.putString("password", password);
  preferences.end();

  Serial.println("WiFi credentials saved to NVS");
}

// Clear WiFi credentials from NVS (factory reset)
void clearWiFiCredentials() {
  Preferences preferences;
  preferences.begin(WIFI_NVS_NAMESPACE, false);
  preferences.clear();
  preferences.end();

  Serial.println("WiFi credentials cleared from NVS");
}

// Initialize BLE (call once at boot)
void initBLEProvisioning() {
  BLEDevice::init(getBLEDeviceName().c_str());
  Serial.print("BLE: Initialized as '");
  Serial.print(getBLEDeviceName());
  Serial.println("'");
}

// Start BLE provisioning mode
void startBLEProvisioning() {
  if (bleProvisioningActive) {
    Serial.println("BLE: Already active");
    return;
  }

  Serial.println("\n=== BLE PROVISIONING MODE ===");
  Serial.print("Device name: ");
  Serial.println(getBLEDeviceName());
  Serial.println("Waiting for mobile app to connect...");

  // Create BLE Server
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  // Create BLE Service
  BLEService *pService = pServer->createService(SERVICE_UUID);

  // Create BLE Characteristic (write + notify)
  BLECharacteristic *pCharacteristic = pService->createCharacteristic(
                                         CHARACTERISTIC_UUID,
                                         BLECharacteristic::PROPERTY_READ   |
                                         BLECharacteristic::PROPERTY_WRITE  |
                                         BLECharacteristic::PROPERTY_NOTIFY
                                       );

  pCharacteristic->addDescriptor(new BLE2902());
  pCharacteristic->setCallbacks(new WiFiCredentialsCallbacks());
  pCharacteristic->setValue("{\"status\":\"ready\",\"message\":\"Send WiFi credentials\"}");

  // Start the service
  pService->start();

  // Start advertising
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);  // iPhone connection interval
  pAdvertising->setMinPreferred(0x12);
  BLEDevice::startAdvertising();

  bleProvisioningActive = true;
  Serial.println("BLE: Advertising started");
  Serial.println("=============================\n");
}

// Stop BLE provisioning mode
void stopBLEProvisioning() {
  if (!bleProvisioningActive) return;

  BLEDevice::deinit(true);
  bleProvisioningActive = false;
  Serial.println("BLE: Stopped");
}

// Process pending credentials (call from main loop)
// This is separated from onWrite() to avoid blocking BLE write acknowledgement
void processPendingCredentials() {
  if (!credentialsPending) return;
  if (pCredentialCharacteristic == nullptr) return;

  // Clear flag immediately to avoid reprocessing
  credentialsPending = false;
  String jsonData = pendingCredentialsJSON;
  pendingCredentialsJSON = "";

  Serial.println("\n[BLE] Processing WiFi credentials:");
  Serial.println(jsonData);

  // Parse JSON: {"ssid":"MyNetwork","password":"secret123"}
  StaticJsonDocument<256> doc;
  DeserializationError error = deserializeJson(doc, jsonData.c_str());

  if (error) {
    Serial.print("BLE: JSON parse error: ");
    Serial.println(error.c_str());
    pCredentialCharacteristic->setValue("{\"status\":\"error\",\"message\":\"Invalid JSON\"}");
    pCredentialCharacteristic->notify();
    return;
  }

  const char* ssid = doc["ssid"];
  const char* password = doc["password"];

  if (ssid == nullptr || password == nullptr) {
    Serial.println("BLE: Missing ssid or password field");
    pCredentialCharacteristic->setValue("{\"status\":\"error\",\"message\":\"Missing ssid or password\"}");
    pCredentialCharacteristic->notify();
    return;
  }

  // Validate credentials
  if (strlen(ssid) == 0 || strlen(ssid) > 32) {
    Serial.println("BLE: SSID invalid length");
    pCredentialCharacteristic->setValue("{\"status\":\"error\",\"message\":\"SSID must be 1-32 characters\"}");
    pCredentialCharacteristic->notify();
    return;
  }

  if (strlen(password) < 8 || strlen(password) > 63) {
    Serial.println("BLE: Password invalid length");
    pCredentialCharacteristic->setValue("{\"status\":\"error\",\"message\":\"Password must be 8-63 characters\"}");
    pCredentialCharacteristic->notify();
    return;
  }

  // Save to NVS
  saveWiFiCredentials(String(ssid), String(password));

  Serial.println("BLE: Credentials saved successfully!");
  Serial.print("  SSID: ");
  Serial.println(ssid);
  Serial.println("  Password: ********");

  // Send success response
  pCredentialCharacteristic->setValue("{\"status\":\"success\",\"message\":\"WiFi configured. Device will reboot.\"}");
  pCredentialCharacteristic->notify();

  credentialsReceived = true;

  // Give client time to receive response, then reboot
  // iPhone BLE requires longer delay to ensure notification is received
  Serial.println("BLE: Sending success notification...");
  delay(2500);  // Increased from 1000ms to 2500ms
  Serial.println("\n*** Rebooting to apply WiFi configuration... ***");
  ESP.restart();
}
