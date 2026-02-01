# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

moveOmeter is an IoT elderly monitoring system using mmWave technology. The system consists of three main components:

1. **Picture Frame Device** - ESP32-C6 based hardware with mmWave sensors
2. **Server Backend** - Cloud infrastructure (Supabase) for data storage and analytics
3. **Client Applications** - Web interface and mobile apps (iOS/Android)

The device monitors elderly individuals in their homes, tracking movement patterns, sleep quality, and daily activity metrics. Data is transmitted to the cloud where caretakers can view analytics through web or mobile apps.

## Project Architecture

### Three-Tier System Design

**Embedded Firmware (ESP32-C6)**
- Receives data from mmWave sensors (DF Robot SEN0623 and possibly SEN0610) via UART
- Parses and processes sensor data locally
- Maintains configuration in .ini files for sensor persistence
- Transmits encrypted data to server via MQTT (or similar protocol)
- Each device has unique identifiers: Serial Number, UUID, MAC Address

**Server Infrastructure (Supabase + Digital Ocean)**
- Receives MQTT messages from all deployed devices
- Stores raw sensor data for future re-analysis with improved algorithms
- Performs analytics calculations (movement scores, sleep patterns, step counting)
- Serves web interface and API endpoints for mobile apps
- Implements versioned data processing pipelines for algorithm improvements

**Client Layer (Web + Mobile)**
- Web: moveOmeter.com with login (2FA, passkey, 6-digit codes)
- Mobile: iOS and Android apps with identical functionality to web
- Display real-time and historical analytics:
  - Movement scores, steps per day
  - Wake/sleep times and sleep quality
  - Door open/close events
  - Sudden motion alerts
  - Weekly and monthly trend analysis

### Database Schema (Supabase)

**moveOmeters Table**
- Each entry represents one physical device
- Fields: unique ID, model number ID, SIM card number, UUID, MAC address, manufacture date, manufacture batch

**moveOmeter_Models Table**
- Device model definitions
- Fields: unique ID, sensor capabilities (checkboxes)

**Raw Data Storage**
- All sensor data tagged with UnitID and SensorID
- Design must scale: 100 → 1K → 10K → 1M → 5M customers

**Houses and Users**
- Each customer can have multiple houses
- Each house can have multiple moveOmeters
- Each moveOmeter has House unique ID and name

## Design Principles

Security, encryption, reliability, uptime, scalability, logging, monitoring, and health status check-ins are core requirements worth investing resources in.

## Development Workflow

### When Adding New Features

**Critical Rule:** Any functionality added to the mobile app MUST also be implemented on the web interface. Always design for both platforms simultaneously.

### Data Processing

Analytics calculations should be:
- Cached or pre-computed offline
- Versioned to allow re-running on historical data
- Scalable across different customer volumes

### Device Configuration

mmWave sensor settings from user manuals should be:
- Configurable via commands from ESP32-C6
- Stored in .ini files
- Restored on device power-up

## Scaling Considerations

When designing new features, document scaling implications at these thresholds:
- 100 customers
- 1,000 customers
- 10,000 customers
- 1,000,000 customers
- 5,000,000 customers

All raw sensor data must be retained at every scale.

## Hardware Context

**Target Deployment Locations:**
- On tables with other picture frames
- Wall-mounted
- Under beds for sleep analysis

**Primary Sensors:**
- mmWave DF Robot SEN0623 (confirmed)
- mmWave DF Robot SEN0610 (testing for dual-sensor setup)

**Processor:** Adafruit ESP32-C6 Feather

## ESP32-C6 Firmware Development

### Arduino IDE Setup

1. Install ESP32 board support in Arduino IDE
2. Select board: "ESP32C6 Dev Module" or "Adafruit Feather ESP32-C6"
3. Select the appropriate COM/serial port

### Hardware Connections (ESP32-C6 Feather)

**mmWave Sensor UART:**
- GPIO16 (TX) → connects to mmWave RX
- GPIO17 (RX) → connects to mmWave TX
- Standard Serial1 configuration: `Serial1.begin(baud, SERIAL_8N1, RX_PIN, TX_PIN)`

**USB Serial:** Serial object at 115200 baud for debugging

### Current Firmware Projects

**Arduino_mmWave_serialpassthrough**
- Simple UART passthrough for testing mmWave sensors
- Allows viewing sensor output and sending commands via Serial Monitor
- See project README for wiring and usage details
