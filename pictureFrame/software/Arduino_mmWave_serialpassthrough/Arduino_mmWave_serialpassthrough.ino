/*
 * Arduino_mmWave_serialpassthrough
 *
 * Simple serial passthrough for ESP32-C6 Feather to communicate with
 * DF Robot SEN0623 (C1001 mmWave Human Detection system)
 *
 * This allows you to:
 * - View mmWave sensor output on the USB Serial Monitor
 * - Send commands to the mmWave sensor from the Serial Monitor
 *
 * Hardware connections (ESP32-C6 Feather):
 * - mmWave TX -> ESP32-C6 RX (GPIO17 on Feather)
 * - mmWave RX -> ESP32-C6 TX (GPIO16 on Feather)
 * - mmWave GND -> ESP32-C6 GND
 * - mmWave VCC -> ESP32-C6 3.3V or 5V (check sensor requirements)

 Library: https://github.com/DFRobot/DFRobot_HumanDetection/tree/master
 
 */

// Serial port definitions
#define USB_SERIAL Serial      // USB debug serial port
#define MMWAVE_SERIAL Serial1  // UART for mmWave sensor

// UART pins for ESP32-C6 Feather
#define MMWAVE_RX_PIN 17  // ESP32-C6 RX (connect to mmWave TX)
#define MMWAVE_TX_PIN 16  // ESP32-C6 TX (connect to mmWave RX)

// Baud rates
#define USB_BAUD 115200
#define MMWAVE_BAUD 115200 // Higher baud rate used by some DF Robot mmWave sensors

void setup() {
  // Initialize USB Serial for debugging
  USB_SERIAL.begin(USB_BAUD);
  delay(2000);  // Wait for serial port to initialize
  
  // Initialize UART Serial for mmWave sensor
  MMWAVE_SERIAL.begin(MMWAVE_BAUD, SERIAL_8N1, MMWAVE_RX_PIN, MMWAVE_TX_PIN);

  USB_SERIAL.println("=================================");
  USB_SERIAL.println("mmWave Serial Passthrough Started");
  USB_SERIAL.println("=================================");
  USB_SERIAL.print("USB Serial: ");
  USB_SERIAL.print(USB_BAUD);
  USB_SERIAL.println(" baud");
  USB_SERIAL.print("mmWave Serial: ");
  USB_SERIAL.print(MMWAVE_BAUD);
  USB_SERIAL.println(" baud");
  USB_SERIAL.println("RX Pin: GPIO" + String(MMWAVE_RX_PIN));
  USB_SERIAL.println("TX Pin: GPIO" + String(MMWAVE_TX_PIN));
  USB_SERIAL.println("=================================");
  USB_SERIAL.println();
  USB_SERIAL.println("Ready. Data from mmWave will appear below:");
  USB_SERIAL.println();
}

void loop() {
  // Pass data from mmWave sensor to USB Serial
  if (MMWAVE_SERIAL.available()) {
    char c = MMWAVE_SERIAL.read();
    USB_SERIAL.write(c);
  }

  // Pass data from USB Serial to mmWave sensor
  // This allows you to send commands to the sensor from Serial Monitor
  // if (USB_SERIAL.available()) {
  //   char c = USB_SERIAL.read();
  //   MMWAVE_SERIAL.write(c);
  // }
}
