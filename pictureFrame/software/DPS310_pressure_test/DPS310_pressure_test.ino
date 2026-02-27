/*
 * DPS310 Pressure Sensor Test
 *
 * Simple test program to monitor pressure changes in real-time
 * Useful for testing door open/close detection
 *
 * Watch the Serial Monitor and open/close a door to see pressure changes
 */

#include <Adafruit_DPS310.h>

Adafruit_DPS310 dps;

float lastPressure = 0.0;
float maxChange = 0.0;
unsigned long lastPrintTime = 0;
int eventCount = 0;

#define DOOR_EVENT_THRESHOLD 0.3  // Pressure change in hPa to flag as "door event"
#define SAMPLE_RATE 100           // Sample every 100ms (10 Hz)

void setup() {
  Serial.begin(115200);
  //while (!Serial) delay(10);
  delay(5000);
  Serial.println("\n\n=================================");
  Serial.println("DPS310 Pressure Sensor Test");
  Serial.println("=================================\n");

  // Initialize DPS310
  Serial.print("Initializing DPS310 sensor... ");
  if (!dps.begin_I2C()) {
    Serial.println("FAILED!");
    Serial.println("Check wiring:");
    Serial.println("  VIN → 3.3V");
    Serial.println("  GND → GND");
    Serial.println("  SCL → GPIO7");
    Serial.println("  SDA → GPIO6");
    while (1) delay(100);
  }
  Serial.println("SUCCESS!");

  // Configure DPS310
  dps.configurePressure(DPS310_64HZ, DPS310_64SAMPLES);
  dps.configureTemperature(DPS310_64HZ, DPS310_64SAMPLES);

  // Get initial reading
  sensors_event_t temp_event, pressure_event;
  if (dps.getEvents(&temp_event, &pressure_event)) {
    lastPressure = pressure_event.pressure;
    Serial.print("Initial pressure: ");
    Serial.print(lastPressure, 2);
    Serial.println(" hPa");
    Serial.print("Initial temperature: ");
    Serial.print(temp_event.temperature, 2);
    Serial.println(" °C\n");
  }

  Serial.println("Monitoring pressure changes...");
  Serial.println("Try opening/closing a door nearby!\n");
  Serial.println("Time(ms)  | Pressure (hPa) | Change (hPa) | Max Change | Events | Status");
  Serial.println("----------|----------------|--------------|------------|--------|--------");
}

void loop() {
  sensors_event_t temp_event, pressure_event;

  if (dps.getEvents(&temp_event, &pressure_event)) {
    float currentPressure = pressure_event.pressure;
    float currentTemp = temp_event.temperature;
    float change = currentPressure - lastPressure;
    float absChange = abs(change);

    // Track maximum change
    if (absChange > maxChange) {
      maxChange = absChange;
    }

    // Detect door event
    bool isDoorEvent = false;
    if (absChange > DOOR_EVENT_THRESHOLD) {
      eventCount++;
      isDoorEvent = true;
    }

    // Print data every sample
    unsigned long now = millis();
    Serial.print(now);
    Serial.print("\t| ");
    Serial.print(currentPressure, 3);
    Serial.print("\t | ");

    // Show change with sign
    if (change >= 0) Serial.print("+");
    Serial.print(change, 3);
    Serial.print("\t | ");

    Serial.print(maxChange, 3);
    Serial.print("\t | ");
    Serial.print(eventCount);
    Serial.print("\t | ");

    if (isDoorEvent) {
      Serial.print("🚪 DOOR EVENT!");
    } else if (absChange > 0.1) {
      Serial.print("~ pressure changing");
    } else {
      Serial.print("stable");
    }

    Serial.println();

    // Update last pressure
    lastPressure = currentPressure;
  }

  delay(SAMPLE_RATE);
}
