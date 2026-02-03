/*
 * mmWave C1001 Reader for ESP32-C6
 *
 * Reads data from DF Robot SEN0623 (C1001 mmWave Human Detection sensor)
 * using the DFRobot_HumanDetection library
 *
 * Hardware connections (ESP32-C6 Feather):
 * - mmWave TX -> ESP32-C6 RX (GPIO17)
 * - mmWave RX -> ESP32-C6 TX (GPIO16)
 * - mmWave GND -> ESP32-C6 GND
 * - mmWave VCC -> ESP32-C6 5V
 */

#include "DFRobot_HumanDetection.h"

// Serial port definitions
#define USB_SERIAL Serial
#define MMWAVE_SERIAL Serial1

// UART pins for ESP32-C6 Feather
#define MMWAVE_RX_PIN 17  // ESP32-C6 RX (connect to mmWave TX)
#define MMWAVE_TX_PIN 16  // ESP32-C6 TX (connect to mmWave RX)

// Create sensor object
DFRobot_HumanDetection sensor;

void setup() {
  // Initialize USB Serial for debugging
  USB_SERIAL.begin(115200);
  delay(2000);

  USB_SERIAL.println("\n=================================");
  USB_SERIAL.println("C1001 mmWave Sensor Reader");
  USB_SERIAL.println("=================================");

  // Initialize UART Serial for mmWave sensor
  MMWAVE_SERIAL.begin(115200, SERIAL_8N1, MMWAVE_RX_PIN, MMWAVE_TX_PIN);

  // Initialize sensor with Serial1
  USB_SERIAL.print("Initializing sensor... ");

  if (sensor.begin(MMWAVE_SERIAL) != 0) {
    USB_SERIAL.println("FAILED!");
    USB_SERIAL.println("Please check:");
    USB_SERIAL.println("  - Wiring connections");
    USB_SERIAL.println("  - Power supply (5V)");
    USB_SERIAL.println("  - Sensor is powered on");
    while(1) {
      delay(1000);
    }
  }

  USB_SERIAL.println("SUCCESS!");

  // Configure sensor (optional - adjust as needed)
  USB_SERIAL.println("Configuring sensor...");

  // Set sensor mode if needed
  // sensor.configWorkMode(DFRobot_HumanDetection::eSleepMode);
  // sensor.configWorkMode(DFRobot_HumanDetection::eFallingMode);

  USB_SERIAL.println("=================================");
  USB_SERIAL.println("Sensor ready! Reading data...\n");
}

void loop() {
  // Read sensor data
  int ret = sensor.readData();

  if (ret == 0) {
    // Successfully read data
    USB_SERIAL.println("--- Sensor Data ---");

    // Get presence information
    uint8_t presence = sensor.smHumanData(DFRobot_HumanDetection::eHumanPresence);
    USB_SERIAL.print("Human Presence: ");
    USB_SERIAL.println(presence ? "YES" : "NO");

    // Get movement information
    uint8_t movement = sensor.smHumanData(DFRobot_HumanDetection::eHumanMovement);
    USB_SERIAL.print("Movement: ");
    USB_SERIAL.println(movement);

    // Get body movement parameter
    uint8_t bodyMovement = sensor.smHumanData(DFRobot_HumanDetection::eHumanMovingRange);
    USB_SERIAL.print("Body Movement: ");
    USB_SERIAL.println(bodyMovement);

    // Get respiration rate (if available)
    uint8_t respiration = sensor.getBreatheValue();
    USB_SERIAL.print("Respiration Rate: ");
    USB_SERIAL.print(respiration);
    USB_SERIAL.println(" breaths/min");

    // Get heart rate (if available)
    uint8_t heartRate = sensor.getHeartRate();
    USB_SERIAL.print("Heart Rate: ");
    USB_SERIAL.print(heartRate);
    USB_SERIAL.println(" bpm");

    USB_SERIAL.println();
  } else {
    USB_SERIAL.print(".");  // Print dot while waiting for valid data
  }

  delay(1000);  // Read every second
}
