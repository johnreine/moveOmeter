/*
 * Baud Rate Scanner for mmWave Sensor
 * Cycles through common baud rates to find the correct one
 */

#define USB_SERIAL Serial
#define MMWAVE_RX_PIN 17
#define MMWAVE_TX_PIN 16

// Common baud rates to test
uint32_t baudRates[] = {9600, 19200, 38400, 57600, 115200, 230400, 256000, 460800, 921600};
int numRates = sizeof(baudRates) / sizeof(baudRates[0]);
int currentRate = 0;

unsigned long lastSwitch = 0;
const unsigned long SWITCH_INTERVAL = 5000; // 5 seconds per baud rate

void setup() {
  USB_SERIAL.begin(115200);
  delay(2000);

  USB_SERIAL.println("\n\n=================================");
  USB_SERIAL.println("mmWave Baud Rate Scanner");
  USB_SERIAL.println("=================================");
  USB_SERIAL.println("Will test each baud rate for 5 seconds");
  USB_SERIAL.println("Watch for readable text patterns");
  USB_SERIAL.println("=================================\n");

  startBaudRate(currentRate);
}

void startBaudRate(int index) {
  Serial1.end();
  delay(100);
  Serial1.begin(baudRates[index], SERIAL_8N1, MMWAVE_RX_PIN, MMWAVE_TX_PIN);

  USB_SERIAL.println("\n--- Testing: " + String(baudRates[index]) + " baud ---");
  lastSwitch = millis();
}

void loop() {
  // Check if it's time to switch to next baud rate
  if (millis() - lastSwitch >= SWITCH_INTERVAL) {
    currentRate++;
    if (currentRate >= numRates) {
      currentRate = 0;
      USB_SERIAL.println("\n\n=== Cycling back to start ===\n");
    }
    startBaudRate(currentRate);
  }

  // Pass data from mmWave sensor to USB Serial
  while (Serial1.available()) {
    char c = Serial1.read();
    USB_SERIAL.write(c);
  }
}
