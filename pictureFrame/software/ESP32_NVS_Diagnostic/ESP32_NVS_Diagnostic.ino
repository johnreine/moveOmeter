/*
 * ESP32 NVS and WiFi Credentials Diagnostic Tool
 *
 * This sketch checks:
 * - NVS partition health
 * - WiFi credentials storage
 * - Flash integrity
 * - What might have caused credential loss
 */

#include <WiFi.h>
#include <Preferences.h>
#include <nvs_flash.h>
#include <nvs.h>

Preferences preferences;

void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial.println("\n\n");
  Serial.println("╔════════════════════════════════════════╗");
  Serial.println("║  ESP32 NVS Diagnostic Tool             ║");
  Serial.println("╚════════════════════════════════════════╝");
  Serial.println();

  // 1. Check NVS Stats
  checkNVSStats();

  // 2. Check WiFi credentials
  checkWiFiCredentials();

  // 3. Check custom preferences
  checkCustomPreferences();

  // 4. Check for corruption
  checkNVSHealth();

  // 5. List all NVS entries
  listAllNVSEntries();

  Serial.println("\n╔════════════════════════════════════════╗");
  Serial.println("║  Diagnostic Complete                   ║");
  Serial.println("╚════════════════════════════════════════╝");
}

void loop() {
  // Nothing to do
  delay(1000);
}

void checkNVSStats() {
  Serial.println("=== NVS Partition Stats ===");

  nvs_stats_t nvs_stats;
  esp_err_t err = nvs_get_stats(NULL, &nvs_stats);

  if (err == ESP_OK) {
    Serial.printf("Used entries:      %d\n", nvs_stats.used_entries);
    Serial.printf("Free entries:      %d\n", nvs_stats.free_entries);
    Serial.printf("Total entries:     %d\n", nvs_stats.total_entries);
    Serial.printf("Namespace count:   %d\n", nvs_stats.namespace_count);
    Serial.printf("Utilization:       %.1f%%\n",
      (nvs_stats.used_entries * 100.0) / nvs_stats.total_entries);
  } else {
    Serial.printf("ERROR: Failed to get NVS stats (0x%X)\n", err);
  }
  Serial.println();
}

void checkWiFiCredentials() {
  Serial.println("=== WiFi Credentials Check ===");

  // ESP32 stores WiFi credentials in NVS namespace "nvs.net80211"
  // We can check if they exist using WiFi library

  wifi_config_t wifi_config;
  esp_err_t err = esp_wifi_get_config(WIFI_IF_STA, &wifi_config);

  if (err == ESP_OK) {
    if (strlen((char*)wifi_config.sta.ssid) > 0) {
      Serial.printf("✓ WiFi SSID stored: %s\n", wifi_config.sta.ssid);
      Serial.printf("✓ WiFi Password: %s\n",
        strlen((char*)wifi_config.sta.password) > 0 ? "[SET]" : "[EMPTY]");
      Serial.printf("  Password length: %d chars\n", strlen((char*)wifi_config.sta.password));
    } else {
      Serial.println("✗ No WiFi SSID stored");
      Serial.println("  This is why provisioning mode started!");
    }
  } else {
    Serial.printf("ERROR: Failed to read WiFi config (0x%X)\n", err);
  }
  Serial.println();
}

void checkCustomPreferences() {
  Serial.println("=== Custom Preferences Check ===");

  // Check common namespaces used by moveOmeter
  const char* namespaces[] = {
    "moveometer",
    "wifi",
    "config",
    "sensor",
    "supabase"
  };

  for (int i = 0; i < 5; i++) {
    if (preferences.begin(namespaces[i], true)) { // read-only
      Serial.printf("Namespace '%s': EXISTS\n", namespaces[i]);
      preferences.end();
    } else {
      Serial.printf("Namespace '%s': not found\n", namespaces[i]);
    }
  }
  Serial.println();
}

void checkNVSHealth() {
  Serial.println("=== NVS Health Check ===");

  // Try to initialize NVS
  esp_err_t err = nvs_flash_init();

  switch (err) {
    case ESP_OK:
      Serial.println("✓ NVS initialized successfully");
      Serial.println("  No corruption detected");
      break;

    case ESP_ERR_NVS_NO_FREE_PAGES:
      Serial.println("✗ NVS has no free pages!");
      Serial.println("  This could cause write failures");
      Serial.println("  Recommendation: Erase and reinitialize NVS");
      break;

    case ESP_ERR_NVS_NEW_VERSION_FOUND:
      Serial.println("⚠ NVS version mismatch detected");
      Serial.println("  This can happen after firmware updates");
      Serial.println("  Erasing and reinitializing...");
      nvs_flash_erase();
      nvs_flash_init();
      break;

    default:
      Serial.printf("✗ NVS initialization error: 0x%X\n", err);
      Serial.println("  NVS may be corrupted");
      break;
  }
  Serial.println();
}

void listAllNVSEntries() {
  Serial.println("=== NVS Contents ===");
  Serial.println("(Attempting to list some common entries)");

  // Open WiFi namespace
  nvs_handle_t nvs_handle;
  esp_err_t err = nvs_open("nvs.net80211", NVS_READONLY, &nvs_handle);

  if (err == ESP_OK) {
    Serial.println("\nNamespace 'nvs.net80211' (WiFi):");

    // Try to read some common keys
    char ssid[33] = {0};
    size_t ssid_len = sizeof(ssid);
    err = nvs_get_str(nvs_handle, "sta.ssid", ssid, &ssid_len);
    if (err == ESP_OK) {
      Serial.printf("  sta.ssid: %s\n", ssid);
    } else {
      Serial.printf("  sta.ssid: not found (0x%X)\n", err);
    }

    nvs_close(nvs_handle);
  } else {
    Serial.printf("  Could not open WiFi namespace (0x%X)\n", err);
    Serial.println("  This means WiFi credentials are definitely gone!");
  }

  Serial.println();
}
