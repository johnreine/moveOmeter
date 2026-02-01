# SM-24 Geophone Front-End - Enhanced Version 2.0

## Overview

Enhanced analog front-end for detecting floor vibrations from footsteps, optimized for gait analysis in elderly monitoring systems.

**Key Features:**
- Input protection (ESD/transient)
- Dual gain stages (~1100x total)
- Lower cutoff filter (24 Hz) optimized for gait
- 24-bit ADC with internal PGA
- Single 3.3V supply

## Block Diagram

```
                            ┌─────────────────────────────────────────────────────────────────────────┐
                            │                        +3.3V (filtered)                                 │
                            │                              │                                          │
                            │    FB1                      ┌┴┐                                         │
          PWR IN ───────────┴───[####]───┬───────────────│ │ BULK                                    │
                                         │               └┬┘                                         │
                                        ─┴─               │                                          │
                                        GND              GND                                         │
                                                                                                     │
                                                                                                     │
┌─────────┐   R_PROT    ┌─────┐    C1      ┌──────────┐        C3      ┌──────────┐        ┌──────┐ │
│  SM-24  ├───[1k]──┬───┤     ├───┤├───┬───┤  STAGE 1 ├───────┤├──┬───┤  STAGE 2 ├───┬────┤ LPF  ├─┴──► TO ADC
│ Geophone│         │   │ TVS │       │   │   ×101   │           │   │    ×11   │   │    │ 24Hz │
└────┬────┘         │   │ D1  │      ┌┴┐  └──────────┘          ┌┴┐  └──────────┘   │    └──────┘
     │              │   └──┬──┘  R1  │ │                    R5  │ │                 │
    GND             │      │     to  │ │                    to  │ │             ┌───┴───┐
                    │     GND   VCC  │ │                   VCC  │ │             │ADS1220│
                    │               └┬┘                        └┬┘             │24-bit │
                    │           VCC/2│                     VCC/2│              │  ADC  │
                    │               ┌┴┐                        ┌┴┐             └───┬───┘
                    │           R2  │ │                    R6  │ │                 │
                    │               └┬┘                        └┬┘                 │ SPI
                    │                │                          │                  ▼
                    │               GND                        GND             ┌──────┐
                    └──────────────────────────────────────────────────────────┤ MCU  │
                                                                               └──────┘
```

## Design Specifications

| Parameter | Value | Notes |
|-----------|-------|-------|
| Supply Voltage | 3.3V | Single supply, 10-20mA typical |
| **Stage 1 Gain** | 101× (40.1 dB) | 1 + 100k/1k |
| **Stage 2 Gain** | 11× (20.8 dB) | 1 + 100k/10k |
| **Total Analog Gain** | ~1111× (60.9 dB) | Before ADC PGA |
| **Filter Cutoff** | ~24 Hz | Sallen-Key Butterworth |
| Filter Q | 0.707 | Maximally flat passband |
| ADC Resolution | 24 bits | ADS1220 |
| ADC PGA | 1× to 128× | Software configurable |
| **Effective Resolution** | Up to 142,000× | With PGA at 128× |
| Input Protection | ±30V transient | TVS + series resistor |
| Bandwidth | 0.16 Hz to 24 Hz | Set by AC coupling + LPF |

## Why These Specifications for Gait Detection

**~1100× gain**: The SM-24 outputs roughly 28.8 V/(m/s). Typical footstep velocities on wood floors are 0.1-10 mm/s, producing 3-300 µV signals. With 1100× gain, this becomes 3-330 mV - well within the ADC's range while leaving headroom for the PGA.

**24 Hz cutoff**: Human gait cadence is typically 0.5-2 Hz (steps per second), with useful harmonic content extending to about 15-20 Hz. The 24 Hz filter captures all gait information while rejecting higher-frequency noise from HVAC, appliances, etc.

**Dual gain stages with AC coupling**: Breaking the gain into two stages with AC coupling between them prevents DC offset accumulation and allows each stage to operate at its optimal bias point. This improves dynamic range significantly.

## Schematic Details

### Input Protection

```
GEOPHONE+ ───[R_PROT 1k]───┬─── to C1
                          │
                         ─┴─ D1 (PESD5V0S1BL)
                          │
                         GND
```

- **R_PROT (1k)**: Limits current during ESD events to ~5mA at 5V clamp
- **D1**: Bidirectional TVS diode, 5V standoff, <5pF capacitance
- Together they protect the op-amp inputs from static discharge and cable transients

### Gain Stage 1 (~101×)

```
                    +3.3V
                      │
                     ┌┴┐
                R1   │ │ 100k
                     └┬┘
                      │
   from C1 ───┬───────┼─────────┤+ U1A ├───┬─── STAGE1_OUT
              │       │              │     │
             ┌┴┐     ┌┴┐            ─┤     │
        R2   │ │     │ │ C2      R3 ─┤ 1k  │
        100k └┬┘     └┬┘             ├─────┘
              │       │              │
             GND     GND   ┌────────┴────────┐
                           │   R4 (100k)     │
                           └─────────────────┘
                                feedback

Gain = 1 + R4/R3 = 1 + 100k/1k = 101×
```

### Gain Stage 2 (~11×)

```
                    +3.3V
                      │
                     ┌┴┐
                R5   │ │ 100k
                     └┬┘
                      │
from C3 ───┬──────────┼─────────┤+ U2A ├───┬─── STAGE2_OUT
           │          │              │     │
          ┌┴┐        ┌┴┐            ─┤     │
     R6   │ │        │ │ C4     R7  ─┤10k  │
     100k └┬┘        └┬┘            ├─────┘
           │          │             │
          GND        GND  ┌────────┴────────┐
                          │   R8 (100k)     │
                          └─────────────────┘

Gain = 1 + R8/R7 = 1 + 100k/10k = 11×
```

### Sallen-Key Low-Pass Filter (24 Hz)

```
                 R9         R10
STAGE2_OUT ────[47k]───┬───[47k]───┬─────────┤+ U2B ├───┬─── FILT_OUT
                       │           │              │     │
                      ┌┴┐         ┌┴┐             │     │
                 C5   │ │    C6   │ │        ┌────┤-    │
                100nF └┬┘   100nF └┬┘        │    └─────┘
                       │           │         │          │
                      GND         GND        └──────────┘
                                                unity gain feedback

fc = 1 / (2π × R × C × √2) = 1 / (2π × 47k × 100nF × 1.414) ≈ 24 Hz
Q = 0.707 (Butterworth response)
```

## Bill of Materials

| Ref | Value | Package | Description | Qty | DigiKey P/N | ~Cost |
|-----|-------|---------|-------------|-----|-------------|-------|
| **ICs** |
| U1 | OPA2188 | SOIC-8 | Low-noise dual op-amp | 1 | 296-40058-1-ND | $2.50 |
| U2 | OPA2188 | SOIC-8 | Low-noise dual op-amp | 1 | 296-40058-1-ND | $2.50 |
| U3 | ADS1220 | TSSOP-16 | 24-bit delta-sigma ADC | 1 | 296-35377-1-ND | $5.00 |
| **Protection** |
| D1 | PESD5V0S1BL | SOD-882 | Bidirectional TVS, 5V | 1 | 568-13196-1-ND | $0.25 |
| R_PROT | 1k | 0603 | Input protection resistor | 1 | 311-1.00KHRCT-ND | $0.10 |
| FB1 | 600Ω@100MHz | 0805 | Ferrite bead | 1 | 240-2390-1-ND | $0.15 |
| **Stage 1** |
| C1 | 10µF | 0805 | Input coupling | 1 | 1276-1096-1-ND | $0.15 |
| C2 | 10µF | 0805 | Bias bypass | 1 | 1276-1096-1-ND | $0.15 |
| R1 | 100k | 0603 | Bias divider top | 1 | 311-100KHRCT-ND | $0.10 |
| R2 | 100k | 0603 | Bias divider bottom | 1 | 311-100KHRCT-ND | $0.10 |
| R3 | 1k | 0603 | Gain resistor | 1 | 311-1.00KHRCT-ND | $0.10 |
| R4 | 100k | 0603 | Feedback resistor | 1 | 311-100KHRCT-ND | $0.10 |
| **Stage 2** |
| C3 | 10µF | 0805 | Inter-stage coupling | 1 | 1276-1096-1-ND | $0.15 |
| C4 | 10µF | 0805 | Bias bypass | 1 | 1276-1096-1-ND | $0.15 |
| R5 | 100k | 0603 | Bias divider top | 1 | 311-100KHRCT-ND | $0.10 |
| R6 | 100k | 0603 | Bias divider bottom | 1 | 311-100KHRCT-ND | $0.10 |
| R7 | 10k | 0603 | Gain resistor | 1 | 311-10.0KHRCT-ND | $0.10 |
| R8 | 100k | 0603 | Feedback resistor | 1 | 311-100KHRCT-ND | $0.10 |
| **Filter** |
| C5 | 100nF | 0603 | Filter capacitor | 1 | 1276-1005-1-ND | $0.10 |
| C6 | 100nF | 0603 | Filter capacitor | 1 | 1276-1005-1-ND | $0.10 |
| R9 | 47k | 0603 | Filter resistor | 1 | 311-47.0KHRCT-ND | $0.10 |
| R10 | 47k | 0603 | Filter resistor | 1 | 311-47.0KHRCT-ND | $0.10 |
| **Power** |
| C_BULK | 100µF | 1206 | Bulk decoupling | 1 | 1276-6767-1-ND | $0.30 |
| C7 | 10µF | 0805 | Secondary filter | 1 | 1276-1096-1-ND | $0.15 |
| C8 | 100nF | 0603 | U1 bypass | 1 | 1276-1005-1-ND | $0.10 |
| C9 | 100nF | 0603 | U2 bypass | 1 | 1276-1005-1-ND | $0.10 |
| C10 | 100nF | 0603 | U3 AVDD bypass | 1 | 1276-1005-1-ND | $0.10 |
| C11 | 100nF | 0603 | U3 DVDD bypass | 1 | 1276-1005-1-ND | $0.10 |
| **Connectors** |
| J1 | 1×2 | 2.54mm | Geophone input | 1 | 952-2261-ND | $0.50 |
| J2 | 1×6 | 2.54mm | SPI output | 1 | 952-2265-ND | $0.60 |
| J3 | 1×2 | 2.54mm | Power input | 1 | 952-2261-ND | $0.50 |

**Estimated BOM Cost: ~$15-18** (single quantity)

## SPI Connector Pinout (J2)

| Pin | Signal | Description |
|-----|--------|-------------|
| 1 | VCC | 3.3V supply output (for reference) |
| 2 | SCLK | SPI clock input |
| 3 | MISO | SPI data out (DOUT from ADC) |
| 4 | MOSI | SPI data in (DIN to ADC) |
| 5 | CS | Chip select (active low) |
| 6 | GND | Ground |

## Arduino/ESP32 Code

```cpp
#include <SPI.h>

// Pin definitions
const int CS_PIN = 10;
const int DRDY_PIN = 9;

// ADS1220 Commands
#define CMD_RESET    0x06
#define CMD_START    0x08
#define CMD_RDATA    0x10
#define CMD_WREG     0x40

void setup() {
  Serial.begin(115200);
  SPI.begin();
  SPI.setClockDivider(SPI_CLOCK_DIV16); // 1 MHz SPI
  
  pinMode(CS_PIN, OUTPUT);
  pinMode(DRDY_PIN, INPUT);
  digitalWrite(CS_PIN, HIGH);
  
  // Reset the ADC
  digitalWrite(CS_PIN, LOW);
  SPI.transfer(CMD_RESET);
  digitalWrite(CS_PIN, HIGH);
  delay(10);
  
  // Configure ADC
  // Reg0: AIN0 vs AVSS (single-ended), Gain=1, PGA enabled
  // Reg1: 90 SPS (good balance of speed/noise), normal mode
  // Reg2: Internal 2.048V reference, 50Hz rejection
  // Reg3: Default
  digitalWrite(CS_PIN, LOW);
  SPI.transfer(CMD_WREG | 0x00);
  SPI.transfer(0x04);
  SPI.transfer(0x00);  // Reg0
  SPI.transfer(0x14);  // Reg1
  SPI.transfer(0x40);  // Reg2
  SPI.transfer(0x00);  // Reg3
  digitalWrite(CS_PIN, HIGH);
  
  // Start continuous conversion
  digitalWrite(CS_PIN, LOW);
  SPI.transfer(CMD_START);
  digitalWrite(CS_PIN, HIGH);
  
  Serial.println("Geophone Gait Monitor Ready");
  Serial.println("Time(ms),Raw,Voltage(mV)");
}

// Circular buffer for baseline tracking
#define BUFFER_SIZE 256
int32_t sampleBuffer[BUFFER_SIZE];
int bufferIndex = 0;
int32_t runningSum = 0;

void loop() {
  // Wait for data ready
  while (digitalRead(DRDY_PIN) == HIGH);
  
  // Read 24-bit result
  digitalWrite(CS_PIN, LOW);
  SPI.transfer(CMD_RDATA);
  int32_t raw = 0;
  raw |= ((int32_t)SPI.transfer(0x00) << 16);
  raw |= ((int32_t)SPI.transfer(0x00) << 8);
  raw |= SPI.transfer(0x00);
  digitalWrite(CS_PIN, HIGH);
  
  // Sign extend 24-bit to 32-bit
  if (raw & 0x800000) {
    raw |= 0xFF000000;
  }
  
  // Update running average for baseline removal
  runningSum -= sampleBuffer[bufferIndex];
  sampleBuffer[bufferIndex] = raw;
  runningSum += raw;
  bufferIndex = (bufferIndex + 1) % BUFFER_SIZE;
  
  int32_t baseline = runningSum / BUFFER_SIZE;
  int32_t centered = raw - baseline;
  
  // Convert to millivolts (2.048V ref, 24-bit, gain=1)
  float voltage_at_adc = (float)centered * 2048.0 / 8388608.0;
  
  // Output for plotting
  Serial.print(millis());
  Serial.print(",");
  Serial.print(centered);
  Serial.print(",");
  Serial.println(voltage_at_adc, 3);
  
  // Simple footstep detection
  static int32_t lastCentered = 0;
  static unsigned long lastStepTime = 0;
  
  int32_t derivative = centered - lastCentered;
  lastCentered = centered;
  
  // Detect sharp positive transitions (heel strike)
  if (derivative > 50000 && (millis() - lastStepTime) > 300) {
    Serial.println("# STEP DETECTED");
    lastStepTime = millis();
  }
}
```

## Gait Analysis Features

Key features you can extract from the vibration signal:

| Feature | How to Compute | Clinical Relevance |
|---------|----------------|-------------------|
| Cadence | Count peaks per minute | Slowing may indicate fatigue/decline |
| Step regularity | StdDev of inter-step intervals | Irregularity suggests balance issues |
| Stride symmetry | Compare alternating step amplitudes | Asymmetry may indicate injury/weakness |
| Heel strike intensity | Peak amplitude | Reduced impact may indicate shuffling |

## Tuning for Your Application

### More Gain (weaker signals)
Change R3 from 1k to 470Ω → Stage 1 gain becomes 213×
Total gain: ~2300× (67 dB)

### Less Gain (closer mounting)
Change R7 from 10k to 22k → Stage 2 gain becomes 5.5×
Total gain: ~555× (55 dB)

### Higher Filter Cutoff (faster walking)
Change R9, R10 from 47k to 33k → fc ≈ 34 Hz

### Lower Filter Cutoff (slow shuffling)
Change R9, R10 from 47k to 68k → fc ≈ 16 Hz

## Files in This Package

- `geophone_frontend.kicad_pro` - KiCad project file
- `geophone_frontend.kicad_sch` - Original schematic (v1.0)
- `geophone_frontend_v2.kicad_sch` - Enhanced schematic (v2.0) with protection
- `README.md` - This documentation

## Version History

- **v1.0**: Basic single-stage design, 50 Hz filter
- **v2.0**: Added input protection, dual gain stages, optimized 24 Hz filter for gait
