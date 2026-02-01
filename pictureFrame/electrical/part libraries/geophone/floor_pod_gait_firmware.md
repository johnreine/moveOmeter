# Floor Pod Gait Analysis Firmware
## ESP32-C3 + ADXL355 Floor Vibration Sensor

---

## Part 1: Gait Terminology Glossary

### Temporal Parameters (TIME-BASED — Primary targets for floor vibration sensing)

| Term | Definition | Normal (Elderly) | Clinical Significance |
|------|------------|------------------|----------------------|
| **Step Time** | Time from one foot strike to opposite foot strike | 0.5-0.6 sec | Increased = slower gait |
| **Stride Time** | Time for complete gait cycle (L-R-L or R-L-R) | 1.0-1.2 sec | High variability = fall risk |
| **Cadence** | Steps per minute | 90-125 steps/min | Decreases with age/pathology |
| **Stance Time** | Duration foot is on ground | ~60% of cycle | Increased = cautious gait |
| **Swing Time** | Duration foot is in air | ~40% of cycle | Decreased = shuffling |
| **Double Support Time** | Both feet on ground | 20-30% of cycle | Increased = instability |
| **Single Support Time** | One foot on ground | 35-40% of cycle | Decreased = balance issues |

### Spatial Parameters (DISTANCE-BASED — Harder from single sensor, easier with multiple)

| Term | Definition | Normal (Elderly) | Clinical Significance |
|------|------------|------------------|----------------------|
| **Step Length** | Distance between L and R foot strikes | 50-70 cm | Shortened = many pathologies |
| **Stride Length** | Distance of one full gait cycle | 100-150 cm | < half height = significant |
| **Step Width** | Lateral distance between feet | 8-10 cm (elderly) | Widened = instability |
| **Gait Speed** | Distance / time | 0.9-1.4 m/s | "Vital sign" of aging |

### Gait Variability Metrics (CRITICAL FOR FALL PREDICTION)

| Term | Definition | Clinical Significance |
|------|------------|----------------------|
| **Stride Time Variability** | Standard deviation of stride times | High = cognitive decline, fall risk |
| **Step Time Asymmetry** | Difference between L and R step times | >10% = pathological |
| **Cadence Variability** | Coefficient of variation of cadence | Predicts falls better than speed |
| **Gait Smoothness** | Jerk (derivative of acceleration) | Decreased = early cognitive impairment |

### Pathological Gait Patterns

| Pattern | Key Characteristics | Conditions | Detectable via Floor Vibration? |
|---------|---------------------|------------|--------------------------------|
| **Shuffling** | Feet don't lift, drag along floor | Parkinson's, dementia, frailty | ✅ YES - reduced impact amplitude, sliding friction signature |
| **Festination** | Progressive quickening, short steps, forward lean | Parkinson's | ✅ YES - accelerating cadence, decreasing step time |
| **Freezing of Gait** | Sudden inability to initiate/continue steps | Parkinson's, NPH | ✅ YES - long pauses, irregular timing |
| **Cautious Gait** | Shortened stride, widened base, slow | Fear of falling, vestibular | ✅ YES - low cadence, high double-support |
| **Antalgic Gait** | Limp to avoid pain, asymmetric timing | Arthritis, injury | ✅ YES - asymmetric step times |
| **Ataxic Gait** | Unsteady, wide base, irregular | Cerebellar, alcohol | ✅ YES - high variability, irregular cadence |
| **Hemiparetic Gait** | Asymmetric, circumduction | Stroke | ✅ YES - asymmetric timing and amplitude |
| **Frontal Gait** | Small steps, wide base, "magnetic" | NPH, vascular dementia | ✅ YES - low amplitude, high double-support |
| **Steppage Gait** | High knee lift, foot slap | Foot drop, neuropathy | ✅ YES - distinctive impact pattern |

### Impact Characteristics (What the accelerometer actually sees)

| Feature | Description | What It Indicates |
|---------|-------------|-------------------|
| **Heel Strike** | Sharp, high-frequency impulse (50-100 Hz) | Normal initial contact |
| **Flat Foot** | Broader, lower-frequency impact | Shuffling, cautious gait |
| **Toe-Off** | Gentler push-off vibration | Propulsion quality |
| **Impact Amplitude** | Peak acceleration magnitude | Force of footfall, body weight |
| **Rise Time** | Time from onset to peak | Gait control quality |
| **Decay Pattern** | Vibration settling after impact | Floor type, but also gait quality |

---

## Part 2: Data Collection Strategy

### What We Can Measure From a Single Floor Sensor

**HIGH CONFIDENCE (Directly measurable):**
- Step/stride timing (ms precision)
- Cadence (steps/min)
- Step time asymmetry (L vs R)
- Stride time variability (CV%)
- Impact amplitude (relative)
- Presence of shuffling (frequency content)
- Freezing episodes (long gaps)
- Festination (accelerating cadence)

**MEDIUM CONFIDENCE (Requires calibration/learning):**
- Gait speed (needs distance reference or learning)
- Walking direction (multi-axis helps)
- Person identification (ML on vibration signature)

**LOW CONFIDENCE (Better with multiple sensors):**
- Step length (needs localization)
- Step width (needs multiple sensors)
- Exact position in room

### Sampling Strategy

```
ADXL355 Configuration:
- Sample Rate: 1000 Hz (captures all gait frequencies)
- Range: ±2g (maximum sensitivity for light footsteps)
- High-pass filter: 0.5 Hz (remove DC drift)
- Low-pass filter: 200 Hz (anti-alias, focus on gait band)

Key frequency bands:
- 1-10 Hz: Body sway, slow movement
- 10-50 Hz: Footstep fundamental, gait rhythm  
- 50-150 Hz: Heel strike impact, floor resonance
- >150 Hz: Shoe/floor interaction noise
```

---

## Part 3: Firmware Architecture

### System States

```
┌─────────────────────────────────────────────────────────────┐
│                    STATE MACHINE                             │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   ┌──────────┐    motion     ┌──────────┐                  │
│   │  IDLE    │──────────────►│ TRACKING │                  │
│   │ (low pwr)│               │  (1kHz)  │                  │
│   └──────────┘◄──────────────└──────────┘                  │
│        ▲         no motion        │                        │
│        │          (5 sec)         │ walk complete          │
│        │                          ▼                        │
│        │                    ┌──────────┐                   │
│        └────────────────────│ ANALYZE  │                   │
│                             │ (process)│                   │
│                             └──────────┘                   │
└─────────────────────────────────────────────────────────────┘
```

### Core Data Structures

```c
// Raw footstep event
typedef struct {
    uint32_t timestamp_ms;      // Milliseconds since boot
    float peak_amplitude_mg;    // Peak acceleration in milli-g
    float rise_time_ms;         // Time from onset to peak
    float energy;               // Integrated energy of impact
    uint8_t axis;               // Primary axis (usually Z)
    uint8_t impact_type;        // HEEL_STRIKE, FLAT_FOOT, TOE_OFF
} footstep_event_t;

// Gait episode (one walking bout)
typedef struct {
    uint32_t start_time;
    uint32_t end_time;
    uint16_t step_count;
    float step_times[MAX_STEPS];    // Time between consecutive steps
    float amplitudes[MAX_STEPS];    // Impact amplitudes
    
    // Computed metrics
    float cadence_bpm;
    float cadence_cv;               // Coefficient of variation
    float step_time_mean_ms;
    float step_time_std_ms;
    float asymmetry_ratio;          // |L-R| / avg
    float mean_amplitude;
    uint8_t gait_pattern;           // Classification result
} gait_episode_t;

// Long-term trends (daily summary)
typedef struct {
    uint32_t date;                  // YYYYMMDD
    uint16_t total_steps;
    uint16_t walking_bouts;
    float avg_cadence;
    float avg_step_time_variability;
    float avg_asymmetry;
    uint8_t shuffle_episodes;
    uint8_t freeze_episodes;
    uint8_t festination_episodes;
} daily_summary_t;
```

### Main Firmware Code

```cpp
// floor_pod_main.cpp
// ESP32-C3 + ADXL355 Gait Analysis Floor Pod

#include <Arduino.h>
#include <SPI.h>
#include <ADXL355.h>
#include <CircularBuffer.h>

// ============== CONFIGURATION ==============
#define SAMPLE_RATE_HZ      1000
#define ADXL355_CS_PIN      5
#define ADXL355_INT_PIN     6
#define UART_TX_PIN         21
#define UART_BAUD           115200

// Detection thresholds (tune during calibration)
#define NOISE_FLOOR_MG      5.0     // Below this = no activity
#define STEP_THRESHOLD_MG   20.0    // Minimum for footstep
#define MOTION_TIMEOUT_MS   5000    // No motion = end of walk
#define MIN_STEP_TIME_MS    200     // Faster = not walking
#define MAX_STEP_TIME_MS    2000    // Slower = not walking

// Buffer sizes
#define RAW_BUFFER_SIZE     1024    // ~1 second at 1kHz
#define STEP_BUFFER_SIZE    200     // Max steps per episode
#define EPISODE_BUFFER_SIZE 50      // Episodes to store

// ============== GLOBALS ==============
ADXL355 accel(ADXL355_CS_PIN);
CircularBuffer<float, RAW_BUFFER_SIZE> rawBuffer;
CircularBuffer<footstep_event_t, STEP_BUFFER_SIZE> stepBuffer;
CircularBuffer<gait_episode_t, EPISODE_BUFFER_SIZE> episodeBuffer;

volatile bool dataReady = false;
uint32_t lastStepTime = 0;
uint32_t lastMotionTime = 0;
bool trackingActive = false;

// Current episode being built
gait_episode_t currentEpisode;

// ============== INTERRUPT HANDLER ==============
void IRAM_ATTR onDataReady() {
    dataReady = true;
}

// ============== SETUP ==============
void setup() {
    Serial.begin(UART_BAUD);
    Serial1.begin(UART_BAUD, SERIAL_8N1, -1, UART_TX_PIN); // TX only to main unit
    
    // Initialize ADXL355
    SPI.begin();
    accel.begin();
    accel.setRange(ADXL355_RANGE_2G);      // Maximum sensitivity
    accel.setODR(ADXL355_ODR_1000);        // 1kHz sample rate
    accel.setHPF(ADXL355_HPF_0_0095);      // 0.5 Hz high-pass
    
    // Configure interrupt
    pinMode(ADXL355_INT_PIN, INPUT);
    attachInterrupt(digitalPinToInterrupt(ADXL355_INT_PIN), onDataReady, RISING);
    accel.enableDataReadyInt();
    
    // Initialize episode
    memset(&currentEpisode, 0, sizeof(currentEpisode));
    
    Serial.println("{\"event\":\"boot\",\"device\":\"floor_pod\",\"version\":\"1.0\"}");
}

// ============== MAIN LOOP ==============
void loop() {
    static uint32_t lastSample = 0;
    
    if (dataReady) {
        dataReady = false;
        processSample();
    }
    
    // Check for end of walking episode
    if (trackingActive && (millis() - lastMotionTime > MOTION_TIMEOUT_MS)) {
        finalizeEpisode();
    }
    
    // Periodic status (every 10 seconds when idle)
    static uint32_t lastStatus = 0;
    if (!trackingActive && (millis() - lastStatus > 10000)) {
        sendStatus();
        lastStatus = millis();
    }
}

// ============== SAMPLE PROCESSING ==============
void processSample() {
    float x, y, z;
    accel.readAcceleration(&x, &y, &z);
    
    // Use Z-axis primarily (vertical), but compute magnitude for robustness
    float mag = sqrt(x*x + y*y + z*z);
    float z_abs = abs(z);
    
    // Add to raw buffer for analysis
    rawBuffer.push(z_abs);
    
    // Simple threshold detection
    if (z_abs > STEP_THRESHOLD_MG) {
        lastMotionTime = millis();
        
        if (!trackingActive) {
            startEpisode();
        }
        
        // Peak detection with debounce
        if (millis() - lastStepTime > MIN_STEP_TIME_MS) {
            detectFootstep(z_abs, mag);
        }
    }
}

// ============== FOOTSTEP DETECTION ==============
void detectFootstep(float z_peak, float magnitude) {
    // Wait for peak (simple: highest in last 50ms window)
    static float maxInWindow = 0;
    static uint32_t windowStart = 0;
    
    if (millis() - windowStart > 50) {
        if (maxInWindow > STEP_THRESHOLD_MG) {
            // Record footstep
            footstep_event_t step;
            step.timestamp_ms = millis();
            step.peak_amplitude_mg = maxInWindow;
            step.rise_time_ms = estimateRiseTime();
            step.energy = computeEnergy();
            step.impact_type = classifyImpact(maxInWindow, step.rise_time_ms);
            
            stepBuffer.push(step);
            
            // Update episode
            uint32_t stepTime = step.timestamp_ms - lastStepTime;
            if (lastStepTime > 0 && stepTime < MAX_STEP_TIME_MS) {
                currentEpisode.step_times[currentEpisode.step_count] = stepTime;
                currentEpisode.amplitudes[currentEpisode.step_count] = step.peak_amplitude_mg;
                currentEpisode.step_count++;
            }
            
            lastStepTime = step.timestamp_ms;
            
            // Send real-time step event
            sendStepEvent(step);
        }
        
        // Reset window
        maxInWindow = 0;
        windowStart = millis();
    }
    
    if (z_peak > maxInWindow) {
        maxInWindow = z_peak;
    }
}

// ============== IMPACT CLASSIFICATION ==============
// Distinguish heel strike vs flat foot vs toe-off
uint8_t classifyImpact(float amplitude, float riseTime) {
    // Heel strike: high amplitude, fast rise (<10ms)
    // Flat foot: medium amplitude, slow rise (>20ms)  
    // Toe-off: low amplitude, medium rise
    
    if (riseTime < 10 && amplitude > 50) {
        return IMPACT_HEEL_STRIKE;
    } else if (riseTime > 20 || amplitude < 30) {
        return IMPACT_FLAT_FOOT;  // Possible shuffle
    } else {
        return IMPACT_NORMAL;
    }
}

// ============== EPISODE MANAGEMENT ==============
void startEpisode() {
    trackingActive = true;
    memset(&currentEpisode, 0, sizeof(currentEpisode));
    currentEpisode.start_time = millis();
    lastStepTime = 0;
    
    Serial1.println("{\"event\":\"walk_start\"}");
}

void finalizeEpisode() {
    trackingActive = false;
    currentEpisode.end_time = millis();
    
    if (currentEpisode.step_count < 4) {
        // Too few steps, discard
        Serial1.println("{\"event\":\"walk_abort\",\"reason\":\"insufficient_steps\"}");
        return;
    }
    
    // Compute metrics
    computeEpisodeMetrics();
    
    // Classify gait pattern
    currentEpisode.gait_pattern = classifyGaitPattern();
    
    // Store and send
    episodeBuffer.push(currentEpisode);
    sendEpisodeSummary();
}

// ============== GAIT METRICS COMPUTATION ==============
void computeEpisodeMetrics() {
    int n = currentEpisode.step_count;
    if (n < 2) return;
    
    // Step time statistics
    float sum = 0, sumSq = 0;
    for (int i = 0; i < n; i++) {
        sum += currentEpisode.step_times[i];
        sumSq += currentEpisode.step_times[i] * currentEpisode.step_times[i];
    }
    currentEpisode.step_time_mean_ms = sum / n;
    float variance = (sumSq / n) - (currentEpisode.step_time_mean_ms * currentEpisode.step_time_mean_ms);
    currentEpisode.step_time_std_ms = sqrt(variance);
    
    // Cadence
    float duration_sec = (currentEpisode.end_time - currentEpisode.start_time) / 1000.0;
    currentEpisode.cadence_bpm = (n / duration_sec) * 60.0;
    
    // Coefficient of variation (variability metric)
    currentEpisode.cadence_cv = (currentEpisode.step_time_std_ms / currentEpisode.step_time_mean_ms) * 100.0;
    
    // Asymmetry (assume alternating L/R)
    float oddSum = 0, evenSum = 0;
    int oddCount = 0, evenCount = 0;
    for (int i = 0; i < n; i++) {
        if (i % 2 == 0) {
            evenSum += currentEpisode.step_times[i];
            evenCount++;
        } else {
            oddSum += currentEpisode.step_times[i];
            oddCount++;
        }
    }
    float oddMean = oddCount > 0 ? oddSum / oddCount : 0;
    float evenMean = evenCount > 0 ? evenSum / evenCount : 0;
    float avgStepTime = (oddMean + evenMean) / 2.0;
    currentEpisode.asymmetry_ratio = abs(oddMean - evenMean) / avgStepTime;
    
    // Mean amplitude
    float ampSum = 0;
    for (int i = 0; i < n; i++) {
        ampSum += currentEpisode.amplitudes[i];
    }
    currentEpisode.mean_amplitude = ampSum / n;
}

// ============== GAIT PATTERN CLASSIFICATION ==============
#define GAIT_NORMAL         0
#define GAIT_SHUFFLING      1
#define GAIT_FESTINATION    2
#define GAIT_FREEZING       3
#define GAIT_CAUTIOUS       4
#define GAIT_ASYMMETRIC     5
#define GAIT_VARIABLE       6

uint8_t classifyGaitPattern() {
    // Shuffling: low amplitude, high flat-foot ratio
    if (currentEpisode.mean_amplitude < 30) {
        return GAIT_SHUFFLING;
    }
    
    // Festination: accelerating cadence (step times decreasing)
    if (detectFestination()) {
        return GAIT_FESTINATION;
    }
    
    // High variability: CV > 10%
    if (currentEpisode.cadence_cv > 10.0) {
        return GAIT_VARIABLE;
    }
    
    // Asymmetric: asymmetry > 10%
    if (currentEpisode.asymmetry_ratio > 0.10) {
        return GAIT_ASYMMETRIC;
    }
    
    // Cautious: low cadence, long step times
    if (currentEpisode.cadence_bpm < 80 && currentEpisode.step_time_mean_ms > 700) {
        return GAIT_CAUTIOUS;
    }
    
    return GAIT_NORMAL;
}

bool detectFestination() {
    // Check if step times are progressively decreasing
    int n = currentEpisode.step_count;
    if (n < 6) return false;
    
    // Compare first third to last third
    float firstThirdAvg = 0, lastThirdAvg = 0;
    int third = n / 3;
    
    for (int i = 0; i < third; i++) {
        firstThirdAvg += currentEpisode.step_times[i];
    }
    for (int i = n - third; i < n; i++) {
        lastThirdAvg += currentEpisode.step_times[i];
    }
    
    firstThirdAvg /= third;
    lastThirdAvg /= third;
    
    // Festination: last third at least 20% faster
    return (lastThirdAvg < firstThirdAvg * 0.8);
}

// ============== COMMUNICATION ==============
void sendStepEvent(footstep_event_t& step) {
    char buf[128];
    snprintf(buf, sizeof(buf), 
        "{\"event\":\"step\",\"ts\":%lu,\"amp\":%.1f,\"rise\":%.1f,\"type\":%d}",
        step.timestamp_ms, step.peak_amplitude_mg, step.rise_time_ms, step.impact_type);
    Serial1.println(buf);
}

void sendEpisodeSummary() {
    char buf[256];
    snprintf(buf, sizeof(buf),
        "{\"event\":\"episode\",\"steps\":%d,\"cadence\":%.1f,\"cv\":%.2f,"
        "\"asymmetry\":%.3f,\"amplitude\":%.1f,\"pattern\":%d,\"duration\":%lu}",
        currentEpisode.step_count,
        currentEpisode.cadence_bpm,
        currentEpisode.cadence_cv,
        currentEpisode.asymmetry_ratio,
        currentEpisode.mean_amplitude,
        currentEpisode.gait_pattern,
        currentEpisode.end_time - currentEpisode.start_time);
    Serial1.println(buf);
    
    // Also send pattern name for clarity
    const char* patternNames[] = {
        "normal", "shuffling", "festination", "freezing", 
        "cautious", "asymmetric", "variable"
    };
    snprintf(buf, sizeof(buf), "{\"event\":\"gait_class\",\"pattern\":\"%s\"}",
        patternNames[currentEpisode.gait_pattern]);
    Serial1.println(buf);
}

void sendStatus() {
    char buf[128];
    snprintf(buf, sizeof(buf),
        "{\"event\":\"status\",\"uptime\":%lu,\"episodes\":%d}",
        millis() / 1000, episodeBuffer.size());
    Serial1.println(buf);
}

// ============== HELPER FUNCTIONS ==============
float estimateRiseTime() {
    // Look back in raw buffer for onset
    // Simplified: count samples from 10% to 90% of peak
    // Full implementation would use the actual buffer
    return 15.0; // Placeholder
}

float computeEnergy() {
    // Integrate squared acceleration over impact window
    float energy = 0;
    int window = min(50, (int)rawBuffer.size());
    for (int i = rawBuffer.size() - window; i < rawBuffer.size(); i++) {
        float val = rawBuffer[i];
        energy += val * val;
    }
    return energy / window;
}

// ============== DATA LOGGING MODE ==============
// For research/calibration: stream raw data over WiFi

#ifdef DATA_LOGGING_MODE
#include <WiFi.h>
#include <WebServer.h>

WebServer server(80);
bool streamingEnabled = false;

void setupDataLogging() {
    WiFi.begin("SSID", "PASSWORD");
    while (WiFi.status() != WL_CONNECTED) delay(100);
    
    server.on("/stream/start", []() {
        streamingEnabled = true;
        server.send(200, "text/plain", "Streaming started");
    });
    
    server.on("/stream/stop", []() {
        streamingEnabled = false;
        server.send(200, "text/plain", "Streaming stopped");
    });
    
    server.on("/episodes", []() {
        // Return all stored episodes as JSON
        String json = "[";
        for (int i = 0; i < episodeBuffer.size(); i++) {
            // ... format episode as JSON
        }
        json += "]";
        server.send(200, "application/json", json);
    });
    
    server.begin();
}

void streamRawData(float z) {
    if (streamingEnabled) {
        char buf[32];
        snprintf(buf, sizeof(buf), "%lu,%.3f\n", millis(), z);
        // Send via UDP for lowest latency
    }
}
#endif
```

---

## Part 4: Calibration Procedure

### Initial Setup Calibration

```
1. FLOOR CHARACTERIZATION
   - Place pod on floor
   - Walk past at different speeds
   - Record floor resonance frequency
   - Adjust filters if needed

2. THRESHOLD CALIBRATION  
   - Have user walk normally for 1 minute
   - Record typical step amplitudes
   - Set STEP_THRESHOLD_MG to ~50% of average
   - Set NOISE_FLOOR_MG to 2x quiet baseline

3. TIMING VALIDATION
   - Walk with metronome at known cadence
   - Compare measured vs actual cadence
   - Verify timing accuracy within 5%

4. PATTERN BASELINE
   - Record several "normal" walking episodes
   - Establish personal baseline metrics
   - Flag deviations from baseline
```

### Data Collection Protocol for ML Training

```
Collect labeled data:
1. NORMAL walking (label: 0)
2. Simulated SHUFFLING - slide feet (label: 1)  
3. Simulated FESTINATION - start slow, speed up (label: 2)
4. Simulated CAUTIOUS - very slow, small steps (label: 3)
5. ASYMMETRIC - limp simulation (label: 4)

For each:
- 10+ episodes per pattern
- Different users if possible
- Different footwear
- Different times of day
```

---

## Part 5: Output Message Format

### Real-time Events (UART to main unit)

```json
// Boot
{"event":"boot","device":"floor_pod","version":"1.0"}

// Walking started
{"event":"walk_start"}

// Each footstep
{"event":"step","ts":123456,"amp":45.2,"rise":12.3,"type":0}

// Walking episode complete
{"event":"episode","steps":24,"cadence":98.5,"cv":4.2,"asymmetry":0.05,"amplitude":52.3,"pattern":0,"duration":14500}

// Pattern classification
{"event":"gait_class","pattern":"normal"}

// Alert (abnormal pattern detected)
{"event":"alert","type":"shuffling","confidence":0.87,"message":"Shuffling gait detected"}

// Periodic status
{"event":"status","uptime":3600,"episodes":12}
```

### Alert Conditions

| Alert Type | Trigger | Urgency |
|------------|---------|---------|
| `shuffling` | amplitude < threshold, flat-foot impacts | Medium |
| `festination` | accelerating cadence >20% | High |
| `freeze` | >3 sec gap mid-walk | High |
| `high_variability` | CV > 15% | Medium |
| `asymmetry` | >15% L/R difference | Medium |
| `slow_gait` | cadence < 60 bpm | Low |
| `trend_decline` | 7-day trend worsening | Medium |

---

## Part 6: Integration with Main Unit

### Pin Connections

```
Floor Pod (XIAO ESP32C3)     Main Unit (ESP32-S3)
─────────────────────────    ────────────────────
GPIO21 (TX) ─────────────────► GPIO21 (RX) 
GND ─────────────────────────── GND
3.3V ◄─────────────────────────3.3V
                              
(Optional bidirectional)
GPIO20 (RX) ◄────────────────── GPIO22 (TX)
```

### Cable Recommendation

4-conductor shielded cable, 10-15 feet:
- Red: 3.3V power
- Black: GND  
- White: TX (pod to main)
- Green: RX (main to pod, optional)
- Shield: Connect to GND at one end only

### Main Unit Reception Code

```cpp
// On ESP32-S3 main unit
void setupFloorPod() {
    Serial2.begin(115200, SERIAL_8N1, 21, 22); // RX=21, TX=22
}

void processFloorPodMessages() {
    while (Serial2.available()) {
        String line = Serial2.readStringUntil('\n');
        
        // Parse JSON
        StaticJsonDocument<256> doc;
        if (deserializeJson(doc, line) == DeserializationError::Ok) {
            const char* event = doc["event"];
            
            if (strcmp(event, "alert") == 0) {
                // Gait alert - potential fall risk
                const char* alertType = doc["type"];
                float confidence = doc["confidence"];
                handleGaitAlert(alertType, confidence);
            }
            else if (strcmp(event, "episode") == 0) {
                // Store gait metrics for trending
                float cadence = doc["cadence"];
                float cv = doc["cv"];
                float asymmetry = doc["asymmetry"];
                logGaitMetrics(cadence, cv, asymmetry);
            }
        }
    }
}
```

---

## Part 7: Future Enhancements

### Standalone WiFi Mode

```cpp
// Enable for standalone product version
#define STANDALONE_WIFI_MODE

// Features:
// - Web dashboard at http://floor-pod.local
// - MQTT publish to cloud
// - OTA firmware updates
// - Historical data storage on SPIFFS
// - Phone app via BLE
```

### Multi-Sensor Array

With 2-4 floor pods:
- Localization (x,y position of each step)
- Step length measurement
- Walking path tracking
- Room coverage

### ML-Based Classification

Future: Train TensorFlow Lite model on collected data for:
- Better pattern classification
- Person identification
- Anomaly detection
- Predictive fall risk scoring
