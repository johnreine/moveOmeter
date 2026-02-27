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
