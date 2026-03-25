/*
 * BLE Provisioning for WiFi Configuration
 *
 * Allows users to configure WiFi credentials via Bluetooth LE
 * from the moveOmeter mobile app.
 */

#ifndef BLE_PROVISIONING_H
#define BLE_PROVISIONING_H

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <Preferences.h>
#include <ArduinoJson.h>

// BLE UUIDs (generated unique IDs for moveOmeter)
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

// NVS namespace for WiFi credentials
#define WIFI_NVS_NAMESPACE "wifi_config"

// Global state
extern bool bleProvisioningActive;
extern BLEServer* pServer;
extern bool deviceConnected;
extern bool credentialsReceived;
extern bool credentialsPending;  // New: credentials waiting to be processed
extern String pendingCredentialsJSON;  // New: stores received JSON
extern BLECharacteristic* pCredentialCharacteristic;  // New: for sending responses

// WiFi credential storage
struct WiFiCredentials {
  String ssid;
  String password;
  bool isValid;
};

// Function declarations
void initBLEProvisioning();
void startBLEProvisioning();
void stopBLEProvisioning();
void processPendingCredentials();  // New: process credentials in main loop
bool loadWiFiCredentials(WiFiCredentials& creds);
void saveWiFiCredentials(const String& ssid, const String& password);
void clearWiFiCredentials();
String getBLEDeviceName();

// BLE Server Callbacks
class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
      Serial.println("BLE: Client connected");
    };

    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
      Serial.println("BLE: Client disconnected");
      // Restart advertising so another client can connect
      if (bleProvisioningActive) {
        pServer->startAdvertising();
        Serial.println("BLE: Advertising restarted");
      }
    }
};

// BLE Characteristic Callbacks (receives WiFi credentials)
class WiFiCredentialsCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
      String value = pCharacteristic->getValue().c_str();

      if (value.length() > 0) {
        Serial.println("\n[BLE] Received WiFi credentials (queuing for processing)");

        // FAST PATH: Just store the data and set flag
        // Processing happens in main loop to avoid blocking BLE write ACK
        pendingCredentialsJSON = value;
        credentialsPending = true;
        pCredentialCharacteristic = pCharacteristic;  // Save for later response

        Serial.println("BLE: Write acknowledged - processing in main loop...");
        // onWrite returns quickly → BLE write ACK sent immediately
      }
    }
};

#endif
