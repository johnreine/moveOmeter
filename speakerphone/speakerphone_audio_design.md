# Elderly Speakerphone Audio Design Guide
## Achieving Loud, Clear, Full-Duplex Voice Communication

---

## The Core Challenge

Building a speakerphone is **much harder** than building a speaker OR a microphone system. The fundamental problem:

```
┌─────────────────────────────────────────────────────────────┐
│  THE ECHO PROBLEM                                           │
│                                                             │
│  Remote Caller's Voice ──→ [Speaker] ──→ Room ──→ [Mic] ───┐
│                                                             │
│  Without AEC, the remote caller hears their own voice      │
│  delayed by ~50-200ms = UNUSABLE                           │
└─────────────────────────────────────────────────────────────┘
```

Professional speakerphones (Polycom, Jabra) spend **80% of their engineering** on audio processing. Here's how to do it right.

---

## Architecture Overview

### Recommended System Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        AUDIO SUBSYSTEM                                  │
│                                                                         │
│  ┌─────────────┐     ┌─────────────────────────────────────────────┐   │
│  │ MEMS Mics   │────→│           ESP32-S3                          │   │
│  │ (2x array)  │ I2S │  ┌─────────────────────────────────────┐    │   │
│  └─────────────┘     │  │  ESP-SR Audio Front End (AFE)       │    │   │
│                      │  │  ┌─────┐ ┌────┐ ┌────┐ ┌─────┐     │    │   │
│  ┌─────────────┐     │  │  │ AEC │→│ NS │→│AGC │→│ VAD │     │    │   │
│  │Echo Ref Sig │────→│  │  └─────┘ └────┘ └────┘ └─────┘     │    │   │
│  │(from amp)   │ ADC │  └─────────────────────────────────────┘    │   │
│  └─────────────┘     │                    │                        │   │
│                      │                    ▼                        │   │
│                      │           Clean voice to LTE modem          │   │
│                      │                                             │   │
│                      │  ┌─────────────────────────────────────┐    │   │
│                      │  │  Audio from LTE Modem (far-end)     │    │   │
│                      │  └───────────────┬─────────────────────┘    │   │
│                      │                  │                          │   │
│                      └──────────────────┼──────────────────────────┘   │
│                                         │ I2S                          │
│                                         ▼                              │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │              CLASS D AMPLIFIER (5-10W)                           │  │
│  │   ┌────────────┐    ┌────────────┐    ┌────────────────────┐    │  │
│  │   │ I2S Input  │───→│ DAC + Amp  │───→│ Speaker Driver     │    │  │
│  │   └────────────┘    └────────────┘    └────────────────────┘    │  │
│  │                                              │                   │  │
│  │                     Echo Reference ──────────┘                   │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                         │                              │
│                                         ▼                              │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │              SPEAKER SYSTEM                                      │  │
│  │   ┌────────────────────────────────────────────────────────┐    │  │
│  │   │  3" Full-Range Driver + Tuned Wood Enclosure           │    │  │
│  │   │  Target: 90+ dB SPL @ 1m, 150Hz - 15kHz               │    │  │
│  │   └────────────────────────────────────────────────────────┘    │  │
│  └──────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Part 1: Microphone System

### Why Two Microphones?

Two microphones enable:
1. **Beamforming** - Focus on voices from a specific direction
2. **Noise reduction** - Better separation of voice from background noise
3. **Improved AEC** - More robust echo cancellation

### Recommended Microphones

| Microphone | Interface | SNR | Sensitivity | Price | Notes |
|------------|-----------|-----|-------------|-------|-------|
| **INMP441** | I2S | 61dB | -26dBFS | ~$2 | Most common, good value |
| **SPH0645LM4H** | I2S | 65dB | -26dBFS | ~$4 | Higher SNR, Adafruit uses |
| **ICS-43434** | I2S | 65dB | -26dBFS | ~$3 | TDK, very good performance |
| **MSM261S4030H0R** | I2S | 64dB | -26dBFS | ~$2 | Used in ESP32-S3-BOX |

**Recommendation:** Use **2x INMP441** or **2x SPH0645** in an array configuration.

### Microphone Placement

```
┌─────────────────────────────────────────┐
│                                         │
│     [MIC 1]─────40-60mm─────[MIC 2]     │  ← Horizontal array
│                                         │
│              ┌─────────┐                │
│              │ SPEAKER │                │
│              │   ███   │                │
│              └─────────┘                │
│                                         │
│         [  BIG BUTTON  ]                │
│                                         │
└─────────────────────────────────────────┘
         ↑
    User faces this direction
```

**Critical placement rules:**
- Mic spacing: **40-80mm** (ESP-SR requirement)
- Place mics **away from speaker** (reduce direct acoustic coupling)
- Orient mics to face the user
- Avoid placing mics near vibration sources

### Microphone Circuit

```
                    3.3V
                      │
                      ├───[10µF]───┐
                      │            │
                 ┌────┴────┐       │
                 │ INMP441 │       │
                 │         │       │
    BCLK ───────→│ SCK     │       │
    WS ─────────→│ WS      │       │
    DATA ←───────│ SD      │       │
                 │ L/R     │───────┤ (GND=Left, VDD=Right)
                 │ GND     │───────┴───GND
                 └─────────┘

    Wire both mics to same I2S bus, one as Left, one as Right channel
```

---

## Part 2: Echo Cancellation (The Hard Part)

### How AEC Works

```
┌─────────────────────────────────────────────────────────────────┐
│                    AEC BLOCK DIAGRAM                            │
│                                                                 │
│   Far-End Audio ──┬──────────────────────────────→ Speaker     │
│   (from caller)   │                                             │
│                   │                                             │
│                   ▼                                             │
│            ┌─────────────┐                                      │
│            │  Adaptive   │ ← Learns room acoustics              │
│            │   Filter    │                                      │
│            └──────┬──────┘                                      │
│                   │ Estimated Echo                              │
│                   ▼                                             │
│   Mic Input ──→ [  -  ] ──→ Cleaned Voice ──→ To Caller        │
│   (voice+echo)   Subtract                                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### ESP32-S3 + ESP-SR: Built-in AEC

The ESP32-S3 with ESP-SR (Speech Recognition) framework includes:

| Algorithm | Function |
|-----------|----------|
| **AEC** | Acoustic Echo Cancellation - removes speaker output from mic input |
| **NS** | Noise Suppression - removes background noise |
| **AGC** | Automatic Gain Control - normalizes volume levels |
| **VAD** | Voice Activity Detection - knows when someone is speaking |
| **BSS** | Blind Source Separation - beamforming with mic array |

**Resource usage on ESP32-S3:**
- CPU: ~22%
- SRAM: ~48KB
- PSRAM: ~1.1MB

### Echo Reference Signal (CRITICAL!)

For AEC to work, the DSP needs to know exactly what audio is being sent to the speaker. This is called the **echo reference signal**.

**Method 1: Digital Loopback (Recommended)**
```
ESP32-S3 I2S TX ──┬──→ Amplifier ──→ Speaker
                  │
                  └──→ AFE Reference Input (digital copy)
```

**Method 2: Analog Tap from Amplifier Output**
```
Amplifier Output ──┬──→ Speaker
                   │
                   └──→ [Voltage Divider] ──→ [LPF 22kHz] ──→ ADC ──→ AFE Reference
```

ESP-SR input format example: `"MMNR"` = Mic1, Mic2, Null, Reference

### AEC Tuning Guidelines (from Espressif)

| Parameter | Requirement |
|-----------|-------------|
| Reference signal delay | 0-10ms relative to mic signal |
| Speaker THD at max volume | <10% @ 100Hz, <6% @ 200Hz, <3% @ 350Hz+ |
| Mic signal at max volume | Must not clip/saturate |
| Reference voltage | Must not exceed ADC max input |

---

## Part 3: Amplifier Selection

### Why 3W Isn't Enough

The MAX98357A (3W) is popular but **not loud enough** for hard-of-hearing elderly:

| Amplifier Power | SPL with 87dB/W Speaker | Notes |
|-----------------|-------------------------|-------|
| 1W | 87 dB | Quiet conversation |
| 3W | 92 dB | Normal TV volume |
| 5W | 94 dB | Loud, but achievable |
| 10W | 97 dB | Very loud, target for elderly |

**Target: 90-95 dB SPL at 1 meter** (equivalent to 40dB amplification from the search results)

### Amplifier Options

#### Option 1: MAX98357A (Simple, 3W)
- **Pros:** I2S input, simple, cheap (~$5), no external components
- **Cons:** Only 3W, may not be loud enough
- **Use if:** Testing/prototyping, or with very efficient speaker

#### Option 2: MAX98390 (I2S, 10W, with DSP)
- **Specs:** 10W into 4Ω, I2S input, built-in DSP
- **Pros:** More power, integrated speaker protection, I2S
- **Cons:** More expensive (~$15), harder to source
- **Best for:** Production design

#### Option 3: TAS5805M (I2S, 23W)
- **Specs:** 23W mono, I2S input, built-in DSP/EQ
- **Pros:** Very powerful, programmable DSP
- **Cons:** Needs 12-26V supply, more complex
- **Best for:** High-end design

#### Option 4: TPA3116D2 + External DAC (Analog, 50W+)
- **Specs:** 50-100W depending on supply voltage
- **Pros:** Very loud, cheap (~$5), widely available
- **Cons:** Needs separate DAC (PCM5102), higher voltage supply
- **Best for:** Maximum volume

### Recommended: TAS5805M or MAX98390

For a **premium elderly speakerphone**, I recommend:

```
┌─────────────────────────────────────────────────────────────┐
│  TAS5805M Configuration                                     │
│                                                             │
│  ESP32-S3 ──[I2S]──→ TAS5805M ──→ 10W Speaker              │
│             BCLK                                            │
│             LRCLK        12V Supply                         │
│             DIN          │                                  │
│                          ▼                                  │
│                    ┌──────────┐                             │
│                    │ TAS5805M │                             │
│                    │          │──→ OUTP ──┐                 │
│                    │          │           │ BTL Output      │
│                    │          │──→ OUTN ──┴──→ Speaker      │
│                    └──────────┘                             │
│                                                             │
│  Features:                                                  │
│  - Built-in EQ (boost voice frequencies 1-4kHz)            │
│  - Limiter (prevent clipping at max volume)                │
│  - Thermal protection                                       │
│  - I2C control for volume                                   │
└─────────────────────────────────────────────────────────────┘
```

---

## Part 4: Speaker Selection

### Speaker Requirements for Elderly

| Parameter | Target | Why |
|-----------|--------|-----|
| Sensitivity | 87+ dB/W/m | Louder with less power |
| Frequency Response | 150Hz - 12kHz | Voice intelligibility |
| Size | 3" (76mm) | Balance of bass and size |
| Impedance | 4Ω or 8Ω | Common, efficient |
| Power Handling | 5-10W | Match amplifier |

### Recommended Speakers

#### Budget (~$5-10):
- **Visaton FR 7** - 2.5", 8Ω, 88dB, excellent voice clarity
- **Dayton Audio CE65W-8** - 2.5", 8Ω, 82dB, good bass

#### Mid-range (~$15-25):
- **Dayton Audio ND65-8** - 2.5", 8Ω, 83.7dB, reference quality
- **Tang Band W3-881SJ** - 3", 8Ω, 86dB, excellent full-range

#### Premium (~$30-50):
- **Fountek FR89EX** - 3", 8Ω, 87dB, audiophile quality
- **Markaudio Alpair 5** - 3", 8Ω, 85dB, exceptional clarity

**Recommendation:** **Visaton FR 7** or **Tang Band W3-881SJ** - both excellent for voice.

### Enclosure Design

A proper enclosure is **critical** for loud, clear audio. The wood enclosure you mentioned is excellent!

```
┌─────────────────────────────────────────────────────────────┐
│  SEALED ENCLOSURE (Recommended for simplicity)              │
│                                                             │
│    ┌───────────────────────────────────────────┐            │
│    │                                           │            │
│    │     ████████████████████████             │ ← Speaker   │
│    │     ████████████████████████             │    driver   │
│    │                                           │            │
│    │        ┌─────────────────┐               │            │
│    │        │  Damping        │               │            │
│    │        │  Material       │               │ ← Polyester │
│    │        │  (polyfill)     │               │    fill     │
│    │        └─────────────────┘               │            │
│    │                                           │            │
│    └───────────────────────────────────────────┘            │
│                                                             │
│  Internal volume: ~0.5-1 liter for 3" driver                │
│  Material: 12-18mm MDF or hardwood                          │
│  Seal all joints with wood glue                             │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Enclosure calculations for 3" driver:**
- Sealed box volume: ~0.5-1.0 liters (30-60 cubic inches)
- Q factor: Target Qtc = 0.707 for flat response
- Use free software like WinISD to calculate exact volume

#### Passive Radiator Option (Better Bass)
```
┌─────────────────────────────────────────┐
│   [Speaker] ────────────────────────    │
│                                         │
│        [Passive Radiator] ───────────   │ ← Tuned for bass extension
│                                         │
└─────────────────────────────────────────┘
```

A passive radiator extends bass response without a port (which can cause noise).

---

## Part 5: Complete Bill of Materials

### Core Audio Components

| Component | Part Number | Purpose | Price | Source |
|-----------|-------------|---------|-------|--------|
| MCU | ESP32-S3-WROOM-1 (8MB PSRAM) | Main processor + AEC | ~$4 | LCSC, Mouser |
| Mic 1 | INMP441 module | Voice input | ~$2 | Amazon, AliExpress |
| Mic 2 | INMP441 module | Voice input (array) | ~$2 | Amazon, AliExpress |
| Amplifier | TAS5805M module | 10W Class D | ~$12 | Amazon, AliExpress |
| Speaker | Tang Band W3-881SJ | 3" full-range | ~$20 | Parts Express |
| Audio Codec | ES8311 (optional) | ADC for echo ref | ~$3 | AliExpress |

### Alternative (Simpler, Less Loud)

| Component | Part Number | Purpose | Price |
|-----------|-------------|---------|-------|
| MCU | ESP32-S3-WROOM-1 | Main processor | ~$4 |
| Mic x2 | INMP441 | Voice input | ~$4 |
| Amplifier | MAX98357A | 3W I2S amp | ~$5 |
| Speaker | Visaton FR 7 | 2.5" full-range | ~$8 |

### Development Kit Option

If you want to skip the audio design initially:

**ESP32-S3-Korvo-2** (~$50)
- ESP32-S3 with 8MB PSRAM
- 2-mic array with ES7210 ADC
- ES8311 DAC + speaker amp
- **AEC reference signal already routed**
- Ready for ESP-ADF development

---

## Part 6: Software Architecture

### ESP-ADF Pipeline for Speakerphone

```c
// Simplified ESP-ADF pipeline for VoIP speakerphone

// Audio input pipeline (mic → AEC → encoder → network)
[i2s_stream_reader] → [algorithm_stream(AEC+NS+AGC)] → [encoder] → [network_out]

// Audio output pipeline (network → decoder → speaker)  
[network_in] → [decoder] → [i2s_stream_writer]

// Echo reference (critical for AEC)
algorithm_stream needs reference signal from i2s_stream_writer
```

### Key ESP-SR Configuration

```c
afe_config_t afe_config = {
    .aec_init = true,           // Enable AEC
    .se_init = true,            // Enable noise suppression
    .vad_init = true,           // Enable voice activity detection
    .wakenet_init = false,      // Don't need wake word for phone
    .voice_communication_init = true,  // Optimized for voice calls
    .afe_ns_mode = NS_MODE_SSP, // Single-channel noise suppression
    .afe_ns_model_name = "nsnet2",
    .pcm_config = {
        .total_ch_num = 3,      // 2 mics + 1 reference
        .mic_num = 2,
        .ref_num = 1,
        .sample_rate = 16000,
    },
};
```

---

## Part 7: Testing and Tuning

### Echo Cancellation Test Procedure

1. **Echo Return Loss (ERL) Test**
   - Play 1kHz tone through speaker at max volume
   - Measure level at microphone
   - Target: >10dB reduction from AEC

2. **Double-Talk Test**
   - Both local and remote speaking simultaneously
   - Neither should be cut off
   - Test with various volume levels

3. **Convergence Test**
   - Start call in quiet room
   - Walk around room (changing acoustics)
   - AEC should adapt within 1-2 seconds

### Voice Quality Test

1. **Loudness Test**
   - Measure SPL at 1 meter with voice playback
   - Target: 85-95 dB SPL at max volume

2. **Frequency Response**
   - Verify 300Hz-3.4kHz telephone bandwidth
   - Check for excessive bass or treble

3. **Intelligibility Test**
   - Read standardized word lists
   - Have elderly users rate clarity

---

## Part 8: Design Tips for Elderly Users

### Audio Quality Tips

1. **Boost mid-frequencies (1-4kHz)** - Voice intelligibility
2. **Reduce low frequencies (<200Hz)** - Less rumble/muddiness
3. **Add slight compression** - Keeps quiet voices audible
4. **Limit maximum volume** - Prevent hearing damage

### DSP Settings (TAS5805M EQ example)

```
Frequency Response Target:
         +6dB ──────────────────────────
              │         ┌──┐
              │        ╱    ╲
         0dB  ├───────╱      ╲──────────
              │      ╱        ╲
              │     ╱          ╲
        -6dB  ├────╱            ╲────────
              │
              └────────────────────────────
              100   500  1k  2k  4k  8k  Hz
              
              ↑         ↑↑↑
           Cut bass   Boost voice frequencies
```

### Physical Design

1. **Speaker facing UP or toward user** - Direct sound path
2. **Mics on front face** - Facing user
3. **Non-slip base** - Stays in place
4. **Visual feedback** - LED shows call status
5. **LOUD ringer** - Target 85+ dB for alerts

---

## Summary: Recommended Design

### Hardware Stack

```
┌────────────────────────────────────────────────────────────┐
│  SPEAKERPHONE BLOCK DIAGRAM                                │
│                                                            │
│  ┌──────────────┐                                          │
│  │   2x MEMS    │──I2S──┐                                  │
│  │   INMP441    │       │                                  │
│  └──────────────┘       │                                  │
│                         ▼                                  │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐   │
│  │   ES8311     │──→│  ESP32-S3    │──→│   A7670G     │   │
│  │ (echo ADC)   │   │  (AFE+App)   │   │  (LTE/Voice) │   │
│  └──────────────┘   └──────────────┘   └──────────────┘   │
│        ↑                   │                               │
│        │                   │ I2S                           │
│        │                   ▼                               │
│  ┌─────┴────────────────────────────────────────────────┐ │
│  │              TAS5805M (10W Class D)                  │ │
│  │                        │                             │ │
│  │              Echo Ref ─┘                             │ │
│  └─────────────────────────┬────────────────────────────┘ │
│                            │                               │
│                            ▼                               │
│                   ┌────────────────┐                       │
│                   │ Tang Band 3"   │                       │
│                   │ Full Range     │                       │
│                   │ in Wood Box    │                       │
│                   └────────────────┘                       │
│                                                            │
│  Total BOM: ~$50-70                                        │
│  Target Retail: $149-199                                   │
└────────────────────────────────────────────────────────────┘
```

### Development Approach

1. **Phase 1:** Start with ESP32-S3-Korvo-2 dev kit
   - Pre-designed audio with AEC
   - Focus on software/LTE integration
   
2. **Phase 2:** Custom PCB with selected components
   - Optimize speaker/enclosure
   - Add NFC, button, display
   
3. **Phase 3:** Production design
   - Wood enclosure tooling
   - FCC/UL certification

---

## References

- ESP-SR Documentation: https://docs.espressif.com/projects/esp-sr/
- ESP-ADF Examples: https://github.com/espressif/esp-adf/tree/master/examples
- TAS5805M Datasheet: TI Literature Number SLAS702
- Acoustic Echo Cancellation Theory: ITU-T G.167
