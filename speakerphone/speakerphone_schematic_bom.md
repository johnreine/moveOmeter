# Elderly Speakerphone - Quick Reference Schematic & BOM

## Wiring Diagram

```
                                    ┌─────────────────────────────────┐
                                    │         ESP32-S3-WROOM-1        │
                                    │            (8MB PSRAM)          │
                                    │                                 │
    ┌───────────────┐               │  GPIO4  ←── I2S_MIC_BCK        │
    │   INMP441 #1  │───────────────┤  GPIO5  ←── I2S_MIC_WS         │
    │   (Left Mic)  │  I2S          │  GPIO6  ←── I2S_MIC_DATA       │
    │  L/R = GND    │               │                                 │
    └───────────────┘               │  GPIO15 ──→ I2S_SPK_BCK        │
                                    │  GPIO16 ──→ I2S_SPK_WS         │
    ┌───────────────┐               │  GPIO17 ──→ I2S_SPK_DATA       │
    │   INMP441 #2  │───────────────┤                                 │
    │   (Right Mic) │  I2S          │  GPIO18 ──→ I2C_SDA (amp ctrl) │
    │  L/R = VDD    │               │  GPIO19 ──→ I2C_SCL            │
    └───────────────┘               │                                 │
                                    │  GPIO21 ──→ NFC_SDA            │
                                    │  GPIO22 ──→ NFC_SCL            │
                                    │                                 │
    ┌───────────────┐               │  GPIO35 ←── BUTTON (arcade)    │
    │   ES8311      │───────────────┤  GPIO36 ──→ LED_RING (WS2812)  │
    │ (Echo Ref ADC)│  I2S/I2C      │                                 │
    │               │               │  GPIO1/GPIO2 ←→ UART (A7670G)  │
    └───────────────┘               │                                 │
                                    │  EN ←── Power Button            │
                                    └─────────────────────────────────┘
                                                    │
                                                    │ I2S
                                                    ▼
                                    ┌─────────────────────────────────┐
                                    │         TAS5805M                │
                                    │      (10W Class D Amp)          │
                                    │                                 │
                                    │  PVDD ←── 12V                   │
                                    │  DVDD ←── 3.3V                  │
                                    │  GND  ←── GND                   │
                                    │                                 │
                                    │  OUTP ──┬──→ Speaker (+)        │
                                    │  OUTN ──┴──→ Speaker (-)        │
                                    │                                 │
                                    │  PDN  ←── ESP32 GPIO (enable)   │
                                    │  FAULT ──→ ESP32 GPIO (status)  │
                                    └─────────────────────────────────┘
                                                    │
                                                    │ BTL Output
                                                    ▼
                                    ┌─────────────────────────────────┐
                                    │     3" Full-Range Speaker       │
                                    │     (4Ω or 8Ω, 10W)            │
                                    │                                 │
                                    │     In sealed wood enclosure    │
                                    │     ~0.5-1.0 liter volume       │
                                    └─────────────────────────────────┘


    ┌───────────────┐               ┌─────────────────────────────────┐
    │   A7670G      │←── UART ─────→│         ESP32-S3               │
    │  LTE Modem    │               │                                 │
    │               │               │  Audio via I2S or PCM:          │
    │  VoLTE Audio: │               │  - A7670 has PCM interface      │
    │  PCM_CLK      │←─────────────→│  GPIO7                          │
    │  PCM_SYNC     │←─────────────→│  GPIO8                          │
    │  PCM_DIN      │←──────────────│  GPIO9  (ESP32 → Modem)         │
    │  PCM_DOUT     │──────────────→│  GPIO10 (Modem → ESP32)         │
    │               │               │                                 │
    │  SIM Slot     │               │                                 │
    │  Antenna      │               │                                 │
    └───────────────┘               └─────────────────────────────────┘


    ┌───────────────┐
    │   PN532       │
    │  NFC Reader   │──── I2C ────→ ESP32-S3 (GPIO21/22)
    │               │
    │  Card Slot    │←── RFID/NFC Cards with contact photos
    └───────────────┘


    ┌───────────────┐
    │  60mm Arcade  │
    │   Button      │──── GPIO35 (with internal pullup)
    │  w/ LED Ring  │
    │               │
    │  LED Ring     │──── GPIO36 (WS2812 data)
    └───────────────┘
```

---

## Bill of Materials

### Core Electronics

| Qty | Part | Description | Part Number | Price | Source |
|-----|------|-------------|-------------|-------|--------|
| 1 | ESP32-S3 Module | 8MB PSRAM, 16MB Flash | ESP32-S3-WROOM-1-N16R8 | $4.50 | LCSC, Mouser |
| 1 | LTE Modem | Cat-1 with VoLTE | SIMCom A7670G or LILYGO T-A7670G | $25-35 | AliExpress, Amazon |
| 2 | MEMS Microphone | I2S digital output | INMP441 (breakout) | $2 ea | Amazon, AliExpress |
| 1 | Audio Codec | For echo reference | ES8311 (breakout) | $3 | AliExpress |
| 1 | Class D Amplifier | 10W I2S input | TAS5805M (module) | $12 | Amazon, AliExpress |
| 1 | NFC Reader | For contact cards | PN532 (breakout) | $5 | Amazon, AliExpress |

### Audio

| Qty | Part | Description | Part Number | Price | Source |
|-----|------|-------------|-------------|-------|--------|
| 1 | Speaker | 3" full-range, 8Ω, 10W | Tang Band W3-881SJ | $20 | Parts Express |
| 1 | Enclosure | Wood box, ~0.7L | Custom or DIY | $10-30 | - |
| 1 | Damping | Polyester fill | Polyfill | $5 | Parts Express |

### User Interface

| Qty | Part | Description | Part Number | Price | Source |
|-----|------|-------------|-------------|-------|--------|
| 1 | Arcade Button | 60mm illuminated, red | Adafruit 1185 | $5 | Adafruit |
| 1 | LED Ring | 12-LED WS2812 | Adafruit 1643 | $8 | Adafruit |
| 1 | Display | Small OLED (optional) | SSD1306 128x64 | $5 | Amazon |
| 10 | NFC Cards | Blank NTAG215 | NTAG215 cards | $0.50 ea | Amazon |

### Power

| Qty | Part | Description | Part Number | Price | Source |
|-----|------|-------------|-------------|-------|--------|
| 1 | Power Supply | 12V 2A DC adapter | Generic | $8 | Amazon |
| 1 | Buck Converter | 12V → 5V, 3A | LM2596 or MP1584 | $2 | Amazon |
| 1 | LDO | 5V → 3.3V, 500mA | AMS1117-3.3 | $0.20 | LCSC |
| 1 | Battery (optional) | 18650 Li-ion | Samsung 30Q | $5 | - |
| 1 | Charger (optional) | TP4056 with protection | TP4056 module | $1 | AliExpress |

### Connectors & Misc

| Qty | Part | Description | Price |
|-----|------|-------------|-------|
| 1 | SIM Card Holder | Nano-SIM | $0.50 |
| 1 | USB-C Connector | For programming/power | $0.50 |
| 1 | DC Barrel Jack | 5.5x2.1mm | $0.30 |
| 2 | 4-pin JST | For mic connections | $0.20 |
| 1 | 2-pin JST | For speaker | $0.10 |
| - | PCB | Custom 2-layer | $5-10 |
| - | Misc capacitors, resistors | 0603 passives | $2 |

### Total Estimated BOM

| Category | Cost |
|----------|------|
| Core Electronics | ~$55 |
| Audio (speaker + enclosure) | ~$35 |
| User Interface | ~$25 |
| Power | ~$15 |
| Connectors & Misc | ~$10 |
| **TOTAL** | **~$140** |

**Target Retail:** $199-249 (one-time, no subscription required)

---

## Simpler Development Path

### Option A: Start with Dev Kit

**ESP32-S3-Korvo-2** (~$50)
- Already has: 2-mic array, codec, amp, speaker
- AEC reference signal pre-routed
- Just add: A7670G modem, NFC reader, button, enclosure

### Option B: ESP32-S3-BOX-3 (~$45)
- Built-in display, speaker, mics
- Good for rapid prototyping
- Add: A7670G modem, NFC reader, bigger speaker

---

## Key Connections Summary

### I2S Mic Input (from INMP441 array)
```
ESP32-S3         INMP441 #1 (L)    INMP441 #2 (R)
---------        --------------    --------------
GPIO4 (BCLK)  →  SCK            →  SCK
GPIO5 (WS)    →  WS             →  WS  
GPIO6 (DIN)   ←  SD             ←  SD
3.3V          →  VDD            →  VDD
GND           →  GND            →  GND
              →  L/R = GND      →  L/R = 3.3V
```

### I2S Speaker Output (to TAS5805M)
```
ESP32-S3           TAS5805M
---------          --------
GPIO15 (BCLK)   →  SCLK
GPIO16 (WS)     →  LRCLK
GPIO17 (DOUT)   →  SDIN
GPIO18 (SDA)    →  SDA (I2C config)
GPIO19 (SCL)    →  SCL
3.3V            →  DVDD
12V             →  PVDD
GND             →  GND
```

### A7670G LTE Modem (UART + PCM)
```
ESP32-S3           A7670G
---------          ------
GPIO1 (TX)      →  RXD
GPIO2 (RX)      ←  TXD
GPIO3           →  PWRKEY
GPIO7           ↔  PCM_CLK
GPIO8           ↔  PCM_SYNC
GPIO9           →  PCM_DIN (ESP32 audio out)
GPIO10          ←  PCM_DOUT (modem audio in)
```

---

## Software Stack

```
┌─────────────────────────────────────────────────────────────┐
│                    APPLICATION LAYER                        │
│  - Phone call management (dial, answer, hangup)            │
│  - Contact management (NFC cards ↔ phone numbers)          │
│  - LED feedback (calling, connected, error states)         │
│  - Button handler (press = next contact, hold = hangup)    │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                    AUDIO PIPELINE                           │
│  ESP-ADF with:                                             │
│  - algorithm_stream (AEC + NS + AGC)                       │
│  - i2s_stream (mic input, speaker output)                  │
│  - Audio routing to/from LTE modem PCM                     │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                    CELLULAR LAYER                           │
│  AT Commands for A7670G:                                   │
│  - ATD<number>;  (dial)                                    │
│  - ATA          (answer)                                   │
│  - ATH          (hangup)                                   │
│  - AT+CLCC      (call status)                              │
│  - AT+CPCMREG=1 (enable PCM audio)                         │
└─────────────────────────────────────────────────────────────┘
```

---

## Next Steps

1. **Order ESP32-S3-Korvo-2** for audio development
2. **Order LILYGO T-A7670G** for cellular integration  
3. **Test AEC** with ESP-ADF voip example
4. **Design NFC card system** with PN532
5. **Prototype enclosure** with selected speaker
6. **Integrate systems** on custom PCB
