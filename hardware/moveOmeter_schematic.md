# moveOmeter Hardware Schematic
**ESP32-C6 Feather + mmWave SEN0623 Fall Detection Sensor**

## 🔌 Circuit Diagram

```
┌──────────────────────────────────────────────────────────────────────┐
│                      ESP32-C6 FEATHER                                │
│                                                                      │
│  USB-C ───────┬──── Power Input (5V)                                │
│               │                                                      │
│               ├──── 5V Rail ────────────┐                           │
│               │                          │                           │
│               └──── 3.3V Regulator      │                           │
│                          │               │                           │
│                          │               │                           │
│  ┌───────────────────────┼───────────────┼─────────────────────┐   │
│  │                       │               │                     │   │
│  │  GPIO16 (TX1) ────────┼───────────────┼─────────────┐       │   │
│  │  GPIO17 (RX1) ────────┼───────────────┼──────┐      │       │   │
│  │  GPIO5  (PWR) ────────┼───────────────┼────┐ │      │       │   │
│  │                       │               │    │ │      │       │   │
│  │  GND ─────────────────┼───────────────┼──┐ │ │      │       │   │
│  │                       │               │  │ │ │      │       │   │
│  └───────────────────────┼───────────────┼──┼─┼─┼──────┼───────┘   │
│                          │               │  │ │ │      │           │
└──────────────────────────┼───────────────┼──┼─┼─┼──────┼───────────┘
                           │               │  │ │ │      │
                           │               │  │ │ │      │
                       3.3V│           5V ─┘  │ │ │      │
                           │               │  │ │ │      │
                           │               │  │ │ │      │
                           │    ┌──────────┴──┘ │ │      │
                           │    │  MOSFET       │ │      │
                           │    │  (2N7002)     │ │      │
                           │    │               │ │      │
                           │    │   D (Drain)   │ │      │
                           │    │    │          │ │      │
                GPIO5 ─────┼────┤ G (Gate)      │ │      │
                (PWR)      │    │    │          │ │      │
                           │    │   S (Source)  │ │      │
                           │    └────┼──────────┘ │      │
                           │         │GND         │      │
                           │         │            │      │
                           │         │            │      │
        ┌──────────────────┴─────────┴────────────┴──────┴──────┐
        │                                                         │
        │           DF ROBOT SEN0623 mmWAVE SENSOR              │
        │                   (C1001)                              │
        │                                                         │
        │  VCC (5V) ◄───── From MOSFET Drain (Switched 5V)      │
        │  GND      ◄───── GND                                   │
        │  TX       ◄───── GPIO17 (ESP32 RX1)                    │
        │  RX       ◄───── GPIO16 (ESP32 TX1)                    │
        │                                                         │
        └─────────────────────────────────────────────────────────┘
```

---

## 📋 Pin Connections

### ESP32-C6 Feather → mmWave Sensor

| ESP32-C6 Pin | Function | → | mmWave Pin | Wire Color Suggestion |
|--------------|----------|---|------------|----------------------|
| GPIO16 | UART TX | → | RX | Yellow |
| GPIO17 | UART RX | → | TX | Orange |
| 5V (via MOSFET) | Power | → | VCC | Red |
| GND | Ground | → | GND | Black |
| GPIO5 | Power Control | → | MOSFET Gate | Blue |

---

## 🔧 Power Control Circuit (Detailed)

### Component: N-Channel MOSFET (2N7002 or similar)

```
                     +5V (from ESP32)
                       │
                       │
                    ┌──┴──┐
                    │     │
                    │  D  │ ← Drain (to sensor VCC)
                    │     │
         GPIO5 ──┬──┤  G  │ ← Gate (control signal)
                 │  │     │
                 │  │  S  │ ← Source (to GND)
                 │  │     │
                 │  └──┬──┘
                 │     │
                 │    GND
                 │
              10kΩ pull-down
                 │
                GND

```

### Why MOSFET Power Control?

**Problem:** mmWave sensor occasionally needs reset but ESP32 doesn't
**Solution:** ESP32 can power cycle just the sensor via GPIO

**Benefits:**
- Sensor reset without full system reboot
- Can implement automatic recovery
- ESP32 stays connected to WiFi
- Can reset sensor on schedule or error detection

---

## 🛠️ Parts List

| Qty | Component | Part Number | Cost | Source | Notes |
|-----|-----------|-------------|------|--------|-------|
| 1 | ESP32-C6 Feather | Adafruit ESP32-C6 | $15 | Adafruit | Main controller |
| 1 | mmWave Sensor | DF Robot SEN0623 | $30 | DFRobot | Fall detection |
| 1 | N-Channel MOSFET | 2N7002 or AO3400 | $0.50 | DigiKey | Power switch |
| 1 | Resistor 10kΩ | 1/4W | $0.10 | DigiKey | Pull-down |
| 4 | Jumper Wires | 22 AWG | $2 | Amazon | Connections |
| 1 | USB-C Cable | 6ft | $5 | Amazon | Power |
| 1 | Enclosure | 4"x3"x2" | $8 | Amazon | Optional |
| | | | **~$61** | | |

---

## 🔌 Power Specifications

### Power Budget

| Component | Voltage | Current | Power |
|-----------|---------|---------|-------|
| ESP32-C6 (active) | 3.3V | ~80mA | 0.26W |
| ESP32-C6 (WiFi TX) | 3.3V | ~200mA | 0.66W |
| mmWave Sensor | 5V | ~150mA | 0.75W |
| **Total** | | **~430mA** | **~1.7W** |

### Power Supply Options

1. **USB Power (Recommended)**
   - USB-C port on ESP32-C6
   - 5V @ 2A capable
   - Always-on deployment

2. **Battery Power** (Future)
   - LiPo 3.7V 2000mAh
   - ~4-6 hours runtime
   - Add deep sleep: 24+ hours

3. **Wall Adapter**
   - 5V @ 2A USB adapter
   - Clean, regulated power
   - Best for permanent installation

---

## 💻 Software - Power Control Functions

Add these to your Arduino code:

```cpp
// Pin definitions
#define SENSOR_POWER_PIN 5  // GPIO5 controls MOSFET

void setup() {
  // Configure sensor power control pin
  pinMode(SENSOR_POWER_PIN, OUTPUT);
  digitalWrite(SENSOR_POWER_PIN, HIGH);  // Sensor ON by default

  // Rest of setup...
}

// Function to reset sensor
void resetSensor() {
  USB_SERIAL.println("Resetting mmWave sensor...");

  // Power off sensor
  digitalWrite(SENSOR_POWER_PIN, LOW);
  delay(2000);  // Wait 2 seconds

  // Power on sensor
  digitalWrite(SENSOR_POWER_PIN, HIGH);
  delay(10000);  // Wait 10 seconds for sensor init

  // Reconfigure sensor
  sensor.configWorkMode(DFRobot_HumanDetection::eFallingMode);
  sensor.dmInstallHeight(250);

  USB_SERIAL.println("Sensor reset complete!");
}

// Optional: Auto-reset if sensor stops responding
void checkSensorHealth() {
  static int unchangedCount = 0;
  static uint16_t lastTrackX = 0;
  static uint16_t lastTrackY = 0;

  uint16_t trackX = sensor.dmHumanData(DFRobot_HumanDetection::track_x);
  uint16_t trackY = sensor.dmHumanData(DFRobot_HumanDetection::track_y);

  // If position hasn't changed in 20 readings (100 seconds)
  if (trackX == lastTrackX && trackY == lastTrackY) {
    unchangedCount++;
    if (unchangedCount > 20) {
      USB_SERIAL.println("WARNING: Sensor appears frozen!");
      resetSensor();
      unchangedCount = 0;
    }
  } else {
    unchangedCount = 0;
  }

  lastTrackX = trackX;
  lastTrackY = trackY;
}
```

---

## 🔧 Assembly Instructions

### Step 1: Solder Headers (if needed)
- ESP32-C6 Feather usually comes with headers pre-soldered
- If not, solder male headers to ESP32-C6

### Step 2: Wire MOSFET Power Switch
1. **MOSFET Drain** → **5V rail** (red wire)
2. **MOSFET Gate** → **GPIO5** (blue wire) + 10kΩ pull-down resistor to GND
3. **MOSFET Source** → **GND** (black wire)
4. **MOSFET Drain** → **Sensor VCC** (red wire)

### Step 3: Wire UART Communication
1. **ESP32 GPIO16** → **Sensor RX** (yellow wire)
2. **ESP32 GPIO17** → **Sensor TX** (orange wire)

### Step 4: Wire Ground
1. **ESP32 GND** → **Sensor GND** (black wire)

### Step 5: Mount in Enclosure (Optional)
1. Drill holes for USB-C cable
2. Mount ESP32 with standoffs or double-sided tape
3. Mount sensor facing outward
4. Label: "moveOmeter - Fall Detection"

---

## 📐 Physical Layout

```
┌─────────────────────────────────────┐
│  ENCLOSURE (4" x 3" x 2")           │
│                                      │
│  ┌──────────────┐                   │
│  │              │  ◄─ USB-C cable   │
│  │  ESP32-C6    │═══════════════════╗
│  │  Feather     │                   ║
│  │              │                   ║
│  └───┬──────┬───┘                   ║
│      │      │                       ║
│   ┌──┴──────┴──┐                    ║
│   │  MOSFET    │                    ║
│   │  Circuit   │                    ║
│   └──┬─────────┘                    ║
│      │                              ║
│  ┌───┴──────────────┐               ║
│  │                  │               ║
│  │  mmWave Sensor   │ ◄── Faces out║
│  │  (SEN0623)       │               ║
│  │                  │               ║
│  │  [  Sensor  ]    │               ║
│  │  [  Area    ]    │               ║
│  │                  │               ║
│  └──────────────────┘               ║
│                                     ║
└─────────────────────────────────────╝

Side View:
     ║
     ║ Power
     ║
┌────╨─────┐
│  ESP32   │
├──────────┤
│ MOSFET   │
├──────────┤
│          │
│  Sensor  │ ──► Sensing direction
│          │
└──────────┘
```

---

## 🧪 Testing Procedure

### 1. Initial Power-On Test
- [ ] Plug in USB-C cable
- [ ] ESP32 blue LED lights up
- [ ] Serial Monitor shows "Sensor ready!"

### 2. Sensor Detection Test
- [ ] Stand in front of sensor (3-10 feet away)
- [ ] `human_existence` should show `1`
- [ ] Walk around - `track_x` and `track_y` should change

### 3. Power Control Test
- [ ] Upload code with `resetSensor()` function
- [ ] Call `resetSensor()` from Serial Monitor or button
- [ ] Sensor should power off → wait → power on → reinit

### 4. Long-Term Stability Test
- [ ] Run for 24 hours
- [ ] Monitor for frozen sensor values
- [ ] Check if auto-reset triggers

---

## 🔐 Safety Notes

⚠️ **IMPORTANT:**
- Use only 5V power supply (not 12V!)
- MOSFET rating: min 20V, 200mA
- Don't short VCC to GND
- Sensor draws ~150mA - ensure USB supply can handle it
- Mount sensor securely - it's sensitive to vibration

---

## 📊 Pinout Reference

### ESP32-C6 Feather Pinout
```
        USB-C
          ║
    ┌─────╨─────┐
    │           │
5V  │●         ●│ GND
GND │●         ●│ 3V
16  │●  ESP32 ●│ A0
17  │●   C6   ●│ A1
5   │●  Feather●│ A2
6   │●         ●│ SCK
    │●         ●│ MISO
    │●         ●│ MOSI
    │           │
    └───────────┘
```

### SEN0623 Sensor Pinout
```
    ┌───────────┐
    │  Sensor   │
    │  [||||]   │ ← Radar antenna
    │           │
    │  ○ VCC    │ (5V)
    │  ○ GND    │ (Ground)
    │  ○ TX     │ (Data out to ESP32 RX)
    │  ○ RX     │ (Data in from ESP32 TX)
    │           │
    └───────────┘
```

---

## 🚀 Next Steps

1. **Order Parts** (~$61 total, 2-5 day shipping)
2. **Assemble Circuit** (30 minutes)
3. **Upload Code with Power Control** (5 minutes)
4. **Test Sensor Reset** (10 minutes)
5. **Deploy** in target location

---

## 📁 File Locations

- **This Schematic:** `hardware/moveOmeter_schematic.md`
- **Firmware:** `pictureFrame/software/mmWave_Supabase_collector/`
- **Database:** `database/`
- **Web Dashboard:** `web/dashboard/`

---

**Need help building this?** Let me know and I can create more detailed assembly photos or video instructions!
