# SM-24 Geophone Front-End with ADS1220 ADC

## Circuit Overview

```
                                    +3.3V
                                      │
                                     ┌┴┐
                                R1   │ │ 100k
                                     └┬┘
     ┌─────────┐                      │
     │  SM-24  │    C1        VCC/2   │        R4 (100k)
     │ Geophone├────┤├────┬────●──────┼────────/\/\/────┐
     │         │  10µF    │           │                  │
     └────┬────┘         ┌┴┐          │    ┌─────┐       │
          │         R1   │ │ 100k     └────┤-  U1A├──────┴───┐
         GND             └┬┘               │  OPA │          │
                          │          ┌─────┤+    │          │
                         ┌┴┐         │     └─────┘          │
                    C2   │ │ 10µF    │                      │
                         └┬┘       VCC/2                    │
                          │          │                      │
                         GND        ┌┴┐                     │
                                R3  │ │ 1k                  │
                                    └┬┘                     │
                                     │                      │
                                    GND                     │
                                                            │
    ┌───────────────────────────────────────────────────────┘
    │
    │  Sallen-Key Low-Pass Filter (50Hz)
    │
    │     R5          R6
    └────/\/\/───┬───/\/\/───┬─────────┤+  U1B ├────┬─────► To ADC
        31.6k   │   31.6k   │         │  OPA  │    │       (AIN0)
               ┌┴┐         ┌┴┐   ┌────┤-     │    │
          C3   │ │100nF    │ │   │    └──────┘    │
               └┬┘         └┬┘   │                │
                │    C4     │    └────────────────┘
               GND        GND


    ADS1220 ADC Connections:
    ┌──────────────────────────────────────────┐
    │  ADS1220                                 │
    │                                          │
    │  AIN0 ◄──── Filter Output               │
    │  AIN1 ◄──── GND (differential ref)      │
    │                                          │
    │  REFP0 ◄─── AVDD (internal 2.048V ref)  │
    │  REFN0 ◄─── GND                         │
    │                                          │
    │  AVDD ◄──── +3.3V                       │
    │  DVDD ◄──── +3.3V                       │
    │  AVSS ◄──── GND                         │
    │  DGND ◄──── GND                         │
    │                                          │
    │  SCLK ────► MCU SPI Clock               │
    │  DOUT ────► MCU MISO                    │
    │  DIN  ◄──── MCU MOSI                    │
    │  CS   ◄──── MCU Chip Select             │
    │  DRDY ────► MCU (interrupt, optional)   │
    └──────────────────────────────────────────┘
```

## Design Parameters

| Parameter | Value | Notes |
|-----------|-------|-------|
| Supply Voltage | 3.3V | Single supply |
| First Stage Gain | 101x (40.1 dB) | 1 + R4/R3 = 1 + 100k/1k |
| Filter Cutoff | ~50 Hz | Sallen-Key 2nd order |
| Filter Q | 0.707 | Butterworth response |
| ADC Resolution | 24 bits | ADS1220 with PGA |
| Sample Rate | Up to 2000 SPS | Configurable |

## Bill of Materials

| Ref | Value | Package | Description | DigiKey P/N |
|-----|-------|---------|-------------|-------------|
| U1 | OPA2188 | SOIC-8 | Low-noise dual op-amp | 296-40058-1-ND |
| U2 | ADS1220 | TSSOP-16 | 24-bit delta-sigma ADC | 296-35377-1-ND |
| C1 | 10µF | 0805 | Input coupling | 1276-1096-1-ND |
| C2 | 10µF | 0805 | Bias bypass | 1276-1096-1-ND |
| C3 | 100nF | 0603 | Filter capacitor | 1276-1005-1-ND |
| C4 | 100nF | 0603 | Filter capacitor | 1276-1005-1-ND |
| C5 | 100µF | 1206 | Power supply bulk | 1276-6767-1-ND |
| C6 | 100nF | 0603 | Op-amp bypass | 1276-1005-1-ND |
| C7 | 100nF | 0603 | ADC AVDD bypass | 1276-1005-1-ND |
| C8 | 100nF | 0603 | ADC DVDD bypass | 1276-1005-1-ND |
| R1 | 100k | 0603 | Bias divider (top) | 311-100KHRCT-ND |
| R2 | 100k | 0603 | Bias divider (bottom) | 311-100KHRCT-ND |
| R3 | 1k | 0603 | Gain set resistor | 311-1.00KHRCT-ND |
| R4 | 100k | 0603 | Feedback resistor | 311-100KHRCT-ND |
| R5 | 31.6k | 0603 | Filter resistor | 311-31.6KHRCT-ND |
| R6 | 31.6k | 0603 | Filter resistor | 311-31.6KHRCT-ND |
| J1 | 1x2 | 2.54mm | Geophone connector | 952-2261-ND |
| J2 | 1x6 | 2.54mm | SPI connector | 952-2265-ND |
| J3 | 1x2 | 2.54mm | Power connector | 952-2261-ND |

## SPI Connector Pinout (J2)

| Pin | Signal | Description |
|-----|--------|-------------|
| 1 | VCC | 3.3V supply |
| 2 | SCLK | SPI clock |
| 3 | MISO | SPI data out (DOUT) |
| 4 | MOSI | SPI data in (DIN) |
| 5 | CS | Chip select (active low) |
| 6 | GND | Ground |

## Component Selection Notes

### Op-Amp (OPA2188)
- Very low offset voltage (±25µV max)
- Low noise (8.8 nV/√Hz)
- Rail-to-rail output
- Alternatives: MCP6022 (cheaper), OPA1612 (lower noise)

### ADC (ADS1220)
- 24-bit resolution
- Built-in PGA (gains 1, 2, 4, 8, 16, 32, 64, 128)
- Internal 2.048V reference
- Up to 2000 SPS
- Differential inputs reduce common-mode noise

### Filter Component Calculations
For a 50Hz Butterworth low-pass filter with Q = 0.707:
```
fc = 1 / (2π × R × C × √2)
With R5 = R6 = 31.6k and C3 = C4 = 100nF:
fc = 1 / (2π × 31.6k × 100nF × 1.414) ≈ 50 Hz
```

## Arduino/ESP32 Code Example

```cpp
#include <SPI.h>

// ADS1220 registers and commands
#define ADS1220_CMD_RESET    0x06
#define ADS1220_CMD_START    0x08
#define ADS1220_CMD_RDATA    0x10
#define ADS1220_CMD_RREG     0x20
#define ADS1220_CMD_WREG     0x40

const int CS_PIN = 10;
const int DRDY_PIN = 9;

void setup() {
  Serial.begin(115200);
  SPI.begin();
  pinMode(CS_PIN, OUTPUT);
  pinMode(DRDY_PIN, INPUT);
  digitalWrite(CS_PIN, HIGH);
  
  // Reset ADS1220
  digitalWrite(CS_PIN, LOW);
  SPI.transfer(ADS1220_CMD_RESET);
  digitalWrite(CS_PIN, HIGH);
  delay(1);
  
  // Configure: AIN0/AIN1 differential, gain=1, 20SPS, internal ref
  digitalWrite(CS_PIN, LOW);
  SPI.transfer(ADS1220_CMD_WREG | 0x00); // Write starting at reg 0
  SPI.transfer(0x04);  // 4 bytes to write
  SPI.transfer(0x01);  // Reg0: AIN0/AIN1, gain=1, PGA enabled
  SPI.transfer(0x04);  // Reg1: 20 SPS, normal mode
  SPI.transfer(0x40);  // Reg2: Internal 2.048V reference
  SPI.transfer(0x00);  // Reg3: Default
  digitalWrite(CS_PIN, HIGH);
  
  // Start continuous conversion
  digitalWrite(CS_PIN, LOW);
  SPI.transfer(ADS1220_CMD_START);
  digitalWrite(CS_PIN, HIGH);
}

void loop() {
  // Wait for data ready
  while (digitalRead(DRDY_PIN) == HIGH);
  
  // Read 24-bit result
  digitalWrite(CS_PIN, LOW);
  SPI.transfer(ADS1220_CMD_RDATA);
  int32_t result = 0;
  result |= ((int32_t)SPI.transfer(0x00) << 16);
  result |= ((int32_t)SPI.transfer(0x00) << 8);
  result |= SPI.transfer(0x00);
  digitalWrite(CS_PIN, HIGH);
  
  // Sign extend 24-bit to 32-bit
  if (result & 0x800000) {
    result |= 0xFF000000;
  }
  
  // Convert to voltage (with 2.048V reference, gain=1)
  float voltage = (float)result * 2.048 / 8388608.0;
  
  Serial.println(voltage, 6);
  delay(50);  // ~20 Hz sample rate
}
```

## PCB Layout Tips

1. **Ground plane**: Use a solid ground plane on bottom layer
2. **Analog/digital separation**: Keep digital traces away from analog input
3. **Decoupling caps**: Place as close to IC pins as possible
4. **Input traces**: Keep short, away from digital signals
5. **Via placement**: Avoid vias in analog signal path
6. **Component placement**: Place in signal flow order (left to right)

## Adjustments for Your Application

**Higher sensitivity (weak signals):**
- Increase R4 to 220k for gain of ~221x (47 dB)
- Add second gain stage if needed

**Lower cutoff frequency (slower gait):**
- Increase R5, R6 to 68k for ~25 Hz cutoff
- Or increase C3, C4 to 220nF

**Higher sample rate:**
- Configure ADS1220 for 330 SPS or higher
- May need to adjust filter cutoff accordingly

**Battery operation:**
- OPA2188 has low quiescent current (~400µA)
- ADS1220 duty cycle mode for power savings
