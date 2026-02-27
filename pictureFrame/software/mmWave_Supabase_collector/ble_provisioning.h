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
        Serial.println("\n[BLE] Received WiFi credentials:");
        Serial.println(value);

        // Parse JSON: {"ssid":"MyNetwork","password":"secret123"}
        StaticJsonDocument<256> doc;
        DeserializationError error = deserializeJson(doc, value.c_str());

        if (error) {
          Serial.print("BLE: JSON parse error: ");
          Serial.println(error.c_str());
          pCharacteristic->setValue("{\"status\":\"error\",\"message\":\"Invalid JSON\"}");
          pCharacteristic->notify();
          return;
        }

        const char* ssid = doc["ssid"];
        const char* password = doc["password"];

        if (ssid == nullptr || password == nullptr) {
          Serial.println("BLE: Missing ssid or password field");
          pCharacteristic->setValue("{\"status\":\"error\",\"message\":\"Missing ssid or password\"}");
          pCharacteristic->notify();
          return;
        }

        // Validate credentials
        if (strlen(ssid) == 0 || strlen(ssid) > 32) {
          Serial.println("BLE: SSID invalid length");
          pCharacteristic->setValue("{\"status\":\"error\",\"message\":\"SSID must be 1-32 characters\"}");
          pCharacteristic->notify();
          return;
        }

        if (strlen(password) < 8 || strlen(password) > 63) {
          Serial.println("BLE: Password invalid length");
          pCharacteristic->setValue("{\"status\":\"error\",\"message\":\"Password must be 8-63 characters\"}");
          pCharacteristic->notify();
          return;
        }

        // Save to NVS
        saveWiFiCredentials(String(ssid), String(password));

        Serial.println("BLE: Credentials saved successfully!");
        Serial.print("  SSID: ");
        Serial.println(ssid);
        Serial.println("  Password: ********");

        // Send success response
        pCharacteristic->setValue("{\"status\":\"success\",\"message\":\"WiFi configured. Device will reboot.\"}");
        pCharacteristic->notify();

        credentialsReceived = true;

        // Give client time to receive response, then reboot
        delay(1000);
        Serial.println("\n*** Rebooting to apply WiFi configuration... ***");
        ESP.restart();
      }
    }
};

#endif
