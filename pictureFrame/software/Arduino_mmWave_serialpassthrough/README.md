# Arduino mmWave Serial Passthrough

Simple serial passthrough program for ESP32-C6 Feather to communicate with the DF Robot SEN0623 (C1001 mmWave Human Detection system).

## Purpose

This test program allows you to:
- View raw data from the mmWave sensor on your computer
- Send configuration commands to the mmWave sensor
- Verify the sensor is working correctly before integration

## Hardware Connections

Connect the DF Robot SEN0623 to the ESP32-C6 Feather:

| mmWave Sensor | ESP32-C6 Feather |
|---------------|------------------|
| TX            | GPIO17 (RX)      |
| RX            | GPIO16 (TX)      |
| GND           | GND              |
| VCC           | 3.3V or 5V       |

**Note:** Check the SEN0623 datasheet for proper voltage (3.3V or 5V).

## How to Use

1. **Upload the sketch**
   - Open `Arduino_mmWave_serialpassthrough.ino` in Arduino IDE
   - Select board: "ESP32C6 Dev Module" or "Adafruit Feather ESP32-C6"
   - Select the correct COM port
   - Click Upload

2. **Open Serial Monitor**
   - Set baud rate to **115200**
   - You should see the startup message
   - Data from the mmWave sensor will appear in the monitor

3. **Send commands to sensor**
   - Type commands in the Serial Monitor input field
   - Commands will be forwarded to the mmWave sensor
   - Sensor responses will appear in the monitor

## Configuration

If the mmWave sensor uses a different baud rate:
- Edit `MMWAVE_BAUD` in the sketch (line 27)
- Common values: 9600, 115200, 256000

## Troubleshooting

**No data appearing:**
- Check wiring connections
- Verify sensor power (LED should be on if present)
- Try different baud rates for MMWAVE_BAUD
- Confirm TX/RX are not swapped

**Garbled data:**
- Wrong baud rate - check sensor documentation
- Possible wiring issue or loose connection

**Cannot upload sketch:**
- Press and hold BOOT button while uploading
- Check USB cable supports data (not just charging)
- Verify correct board and port selected in Arduino IDE
