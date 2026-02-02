// Initialize Supabase client
const { createClient } = window.supabase;
const db = createClient(SUPABASE_CONFIG.url, SUPABASE_CONFIG.anonKey);

// Data storage
let dataBuffer = [];
let charts = {};
let currentMode = 'sleep'; // or 'fall_detection'
let modeDetected = false;  // Track if we've detected the mode from data

// Initialize dashboard
document.addEventListener('DOMContentLoaded', async () => {
    console.log('Dashboard initializing...');

    // Initialize charts
    initializeCharts();

    // Load initial data
    await loadInitialData();

    // Set up real-time subscription
    setupRealtimeSubscription();

    // Set up periodic refresh as backup
    setInterval(loadLatestData, DASHBOARD_CONFIG.refreshInterval);
});

// Mode switching function
function switchMode(mode) {
    currentMode = mode;
    modeDetected = true;  // Mark mode as detected/confirmed

    // Update button states
    document.getElementById('mode-sleep').classList.toggle('active', mode === 'sleep');
    document.getElementById('mode-fall').classList.toggle('active', mode === 'fall_detection');

    // Show/hide metrics and charts
    document.getElementById('sleep-metrics').style.display = mode === 'sleep' ? 'grid' : 'none';
    document.getElementById('fall-metrics').style.display = mode === 'fall_detection' ? 'grid' : 'none';
    document.getElementById('sleep-charts').style.display = mode === 'sleep' ? 'grid' : 'none';
    document.getElementById('fall-charts').style.display = mode === 'fall_detection' ? 'grid' : 'none';

    // Clear and reload data for new mode
    dataBuffer = [];
    loadInitialData();
}

// Initialize all charts
function initializeCharts() {
    const chartOptions = {
        responsive: true,
        maintainAspectRatio: true,
        animation: {
            duration: 300
        },
        scales: {
            y: {
                beginAtZero: true
            }
        },
        plugins: {
            legend: {
                display: true,
                position: 'top'
            }
        }
    };

    // Heart Rate Chart
    charts.heartRate = new Chart(document.getElementById('heartRateChart'), {
        type: 'line',
        data: {
            labels: [],
            datasets: [{
                label: 'Heart Rate (bpm)',
                data: [],
                borderColor: 'rgb(255, 99, 132)',
                backgroundColor: 'rgba(255, 99, 132, 0.1)',
                tension: 0.4,
                fill: true
            }]
        },
        options: chartOptions
    });

    // Respiration Chart
    charts.respiration = new Chart(document.getElementById('respirationChart'), {
        type: 'line',
        data: {
            labels: [],
            datasets: [{
                label: 'Respiration Rate',
                data: [],
                borderColor: 'rgb(54, 162, 235)',
                backgroundColor: 'rgba(54, 162, 235, 0.1)',
                tension: 0.4,
                fill: true
            }]
        },
        options: chartOptions
    });

    // Presence Chart
    charts.presence = new Chart(document.getElementById('presenceChart'), {
        type: 'line',
        data: {
            labels: [],
            datasets: [
                {
                    label: 'Presence',
                    data: [],
                    borderColor: 'rgb(75, 192, 192)',
                    backgroundColor: 'rgba(75, 192, 192, 0.1)',
                    tension: 0.4,
                    yAxisID: 'y'
                },
                {
                    label: 'Movement',
                    data: [],
                    borderColor: 'rgb(255, 159, 64)',
                    backgroundColor: 'rgba(255, 159, 64, 0.1)',
                    tension: 0.4,
                    yAxisID: 'y1'
                }
            ]
        },
        options: {
            ...chartOptions,
            scales: {
                y: {
                    type: 'linear',
                    display: true,
                    position: 'left',
                    title: {
                        display: true,
                        text: 'Presence (0/1)'
                    }
                },
                y1: {
                    type: 'linear',
                    display: true,
                    position: 'right',
                    title: {
                        display: true,
                        text: 'Movement (0-100)'
                    },
                    grid: {
                        drawOnChartArea: false
                    }
                }
            }
        }
    });

    // Sleep Quality Chart
    charts.sleepQuality = new Chart(document.getElementById('sleepQualityChart'), {
        type: 'bar',
        data: {
            labels: [],
            datasets: [{
                label: 'Sleep Quality Score',
                data: [],
                backgroundColor: 'rgba(153, 102, 255, 0.5)',
                borderColor: 'rgb(153, 102, 255)',
                borderWidth: 1
            }]
        },
        options: {
            ...chartOptions,
            scales: {
                y: {
                    beginAtZero: true,
                    max: 100
                }
            }
        }
    });

    // === FALL DETECTION CHARTS ===

    // Fall State Chart
    charts.fallState = new Chart(document.getElementById('fallStateChart'), {
        type: 'line',
        data: {
            labels: [],
            datasets: [{
                label: 'Fall Detected',
                data: [],
                borderColor: 'rgb(239, 68, 68)',
                backgroundColor: 'rgba(239, 68, 68, 0.1)',
                stepped: true,
                fill: true
            }]
        },
        options: chartOptions
    });

    // Motion Chart
    charts.motion = new Chart(document.getElementById('motionChart'), {
        type: 'line',
        data: {
            labels: [],
            datasets: [
                {
                    label: 'Existence (0/1)',
                    data: [],
                    borderColor: 'rgb(34, 197, 94)',
                    backgroundColor: 'rgba(34, 197, 94, 0.1)',
                    tension: 0.4,
                    yAxisID: 'y'
                },
                {
                    label: 'Motion Detected (0/1)',
                    data: [],
                    borderColor: 'rgb(251, 146, 60)',
                    backgroundColor: 'rgba(251, 146, 60, 0.1)',
                    tension: 0.4,
                    yAxisID: 'y'
                },
                {
                    label: 'Body Movement (0-100)',
                    data: [],
                    borderColor: 'rgb(139, 92, 246)',
                    backgroundColor: 'rgba(139, 92, 246, 0.1)',
                    tension: 0.4,
                    yAxisID: 'y1'
                }
            ]
        },
        options: {
            ...chartOptions,
            scales: {
                y: {
                    type: 'linear',
                    display: true,
                    position: 'left',
                    min: 0,
                    max: 1,
                    title: {
                        display: true,
                        text: 'Detection (0/1)'
                    }
                },
                y1: {
                    type: 'linear',
                    display: true,
                    position: 'right',
                    min: 0,
                    max: 100,
                    title: {
                        display: true,
                        text: 'Movement Intensity (0-100)'
                    },
                    grid: {
                        drawOnChartArea: false
                    }
                }
            }
        }
    });

    // Position Scatter Chart (X/Y coordinates)
    charts.position = new Chart(document.getElementById('positionChart'), {
        type: 'scatter',
        data: {
            datasets: [
                {
                    label: 'Sensor Location',
                    data: [{x: 0, y: 0}],  // Sensor at origin
                    backgroundColor: 'rgba(239, 68, 68, 0.7)',
                    borderColor: 'rgb(239, 68, 68)',
                    pointStyle: 'triangle',
                    pointRadius: 12,
                    pointRotation: 0,  // Point upward
                    borderWidth: 2,
                    showLine: false
                },
                {
                    label: 'Movement Trail',
                    data: [],
                    borderColor: 'rgba(156, 163, 175, 0.3)',  // Light gray
                    backgroundColor: 'transparent',
                    borderWidth: 2,
                    pointRadius: 0,  // No dots on the line
                    showLine: true,  // Draw connecting lines
                    tension: 0.3,    // Slight curve
                    fill: false
                },
                {
                    label: 'Person Position',
                    data: [],
                    backgroundColor: 'rgba(99, 102, 241, 0.6)',
                    borderColor: 'rgb(99, 102, 241)',
                    pointStyle: 'circle',
                    pointRadius: 8,
                    borderWidth: 2,
                    showLine: false
                }
            ]
        },
        options: {
            ...chartOptions,
            scales: {
                x: {
                    type: 'linear',
                    position: 'bottom',
                    min: -7.5,
                    max: 7.5,  // 15 feet wide, centered at 0
                    title: {
                        display: true,
                        text: 'X Position (feet)'
                    },
                    grid: {
                        color: 'rgba(0, 0, 0, 0.05)'
                    }
                },
                y: {
                    type: 'linear',
                    min: 0,
                    max: 20,  // 20 feet long
                    title: {
                        display: true,
                        text: 'Y Position (feet)'
                    },
                    grid: {
                        color: 'rgba(0, 0, 0, 0.05)'
                    }
                }
            },
            aspectRatio: 15/20  // Match room proportions
        }
    });

    // Residency Time Chart
    charts.residency = new Chart(document.getElementById('residencyChart'), {
        type: 'bar',
        data: {
            labels: [],
            datasets: [{
                label: 'Time on Floor (seconds)',
                data: [],
                backgroundColor: 'rgba(220, 38, 38, 0.5)',
                borderColor: 'rgb(220, 38, 38)',
                borderWidth: 1
            }]
        },
        options: chartOptions
    });
}

// Load initial historical data
async function loadInitialData() {
    try {
        let query = db
            .from(SUPABASE_CONFIG.table)
            .select('*')
            .order('created_at', { ascending: false })
            .limit(DASHBOARD_CONFIG.maxDataPoints);

        if (DASHBOARD_CONFIG.deviceId) {
            query = query.eq('device_id', DASHBOARD_CONFIG.deviceId);
        }

        // Only filter by mode after we've detected it from the data
        if (modeDetected && currentMode) {
            query = query.eq('sensor_mode', currentMode);
        }

        const { data, error } = await query;

        if (error) throw error;

        if (data && data.length > 0) {
            // Reverse to get chronological order
            dataBuffer = data.reverse();

            // Auto-detect mode from the latest data point (only on first load)
            const latestData = dataBuffer[dataBuffer.length - 1];
            if (!modeDetected && latestData.sensor_mode) {
                if (latestData.sensor_mode !== currentMode) {
                    console.log(`Auto-switching from ${currentMode} to ${latestData.sensor_mode} mode`);
                    modeDetected = true;
                    switchMode(latestData.sensor_mode);
                    return; // switchMode will reload data with correct filter
                } else {
                    // Mode matches, mark as detected
                    modeDetected = true;
                }
            }

            updateAllDisplays();
            console.log(`Loaded ${dataBuffer.length} initial data points in ${currentMode} mode`);
        }
    } catch (error) {
        console.error('Error loading initial data:', error);
        updateConnectionStatus(false);
    }
}

// Load only the latest data point
async function loadLatestData() {
    try {
        let query = db
            .from(SUPABASE_CONFIG.table)
            .select('*')
            .order('created_at', { ascending: false })
            .limit(1);

        if (DASHBOARD_CONFIG.deviceId) {
            query = query.eq('device_id', DASHBOARD_CONFIG.deviceId);
        }

        // Filter by current mode
        query = query.eq('sensor_mode', currentMode);

        const { data, error } = await query;

        if (error) throw error;

        if (data && data.length > 0) {
            addNewDataPoint(data[0]);
        }
    } catch (error) {
        console.error('Error loading latest data:', error);
        updateConnectionStatus(false);
    }
}

// Set up real-time subscription
function setupRealtimeSubscription() {
    const channel = db
        .channel('mmwave_changes')
        .on(
            'postgres_changes',
            {
                event: 'INSERT',
                schema: 'public',
                table: SUPABASE_CONFIG.table,
                filter: DASHBOARD_CONFIG.deviceId ? `device_id=eq.${DASHBOARD_CONFIG.deviceId}` : undefined
            },
            (payload) => {
                console.log('New data received:', payload.new);
                addNewDataPoint(payload.new);
            }
        )
        .subscribe((status) => {
            console.log('Realtime subscription status:', status);
            updateConnectionStatus(status === 'SUBSCRIBED');
        });
}

// Add new data point to buffer
function addNewDataPoint(newData) {
    // Only add if it matches current mode
    if (newData.sensor_mode !== currentMode) {
        return;
    }

    // Add to buffer
    dataBuffer.push(newData);

    // Keep only the last N points
    if (dataBuffer.length > DASHBOARD_CONFIG.maxDataPoints) {
        dataBuffer.shift();
    }

    // Update all displays
    updateAllDisplays();

    // Check for alerts
    checkAlerts(newData);
}

// Update all displays
function updateAllDisplays() {
    if (dataBuffer.length === 0) return;

    const latestData = dataBuffer[dataBuffer.length - 1];

    // Auto-switch to the correct mode based on sensor data
    if (latestData.sensor_mode && latestData.sensor_mode !== currentMode) {
        switchMode(latestData.sensor_mode);
        return; // switchMode will trigger updateAllDisplays again
    }

    // Update current metrics
    updateMetricCards(latestData);

    // Update charts
    updateCharts();

    // Update status bar
    updateStatusBar(latestData);
}

// Update metric cards
function updateMetricCards(data) {
    if (currentMode === 'sleep') {
        // Sleep Mode metrics
        document.getElementById('heart-rate').textContent = data.heart_rate_bpm || '--';
        document.getElementById('respiration').textContent = data.respiration_rate || '--';
        document.getElementById('presence').textContent = data.human_presence ? 'Yes' : 'No';
        document.getElementById('in-bed').textContent = data.in_bed ? 'Yes' : 'No';
        document.getElementById('sleep-quality').textContent = data.stats_sleep_quality_score || '--';
        document.getElementById('apnea').textContent = data.composite_apnea_events || '0';
    } else {
        // Fall Detection metrics
        document.getElementById('fall-state').textContent = data.fall_state ? '🚨 YES' : '✅ No';
        document.getElementById('existence').textContent = data.human_existence ? 'Yes' : 'No';
        document.getElementById('motion').textContent = data.motion_detected ? 'Yes' : 'No';

        // Convert cm to feet (1 ft = 30.48 cm)
        const trackXFeet = data.track_x ? (data.track_x / 30.48).toFixed(1) : '--';
        const trackYFeet = data.track_y ? (data.track_y / 30.48).toFixed(1) : '--';
        document.getElementById('track-x').textContent = trackXFeet;
        document.getElementById('track-y').textContent = trackYFeet;

        // Only show residency time if person is present
        const residencyTime = (data.human_existence > 0) ? (data.static_residency_time_sec || 0) : 0;
        document.getElementById('residency-time').textContent = residencyTime;
    }
}

// Update all charts
function updateCharts() {
    const labels = dataBuffer.map((d, i) => {
        // Use device_timestamp if available, fallback to created_at
        const timestamp = d.device_timestamp || d.created_at;
        const date = new Date(timestamp);
        // Use shorter format with seconds and avoid duplicates by adding index if needed
        const time = date.toLocaleTimeString('en-US', {
            hour: '2-digit',
            minute: '2-digit',
            second: '2-digit',
            hour12: false
        });
        // If this time matches the previous one, add a suffix
        if (i > 0) {
            const prevTimestamp = dataBuffer[i-1].device_timestamp || dataBuffer[i-1].created_at;
            const prevDate = new Date(prevTimestamp);
            const prevTime = prevDate.toLocaleTimeString('en-US', {
                hour: '2-digit',
                minute: '2-digit',
                second: '2-digit',
                hour12: false
            });
            if (time === prevTime) {
                return `${time}.${i % 10}`; // Add sub-second identifier
            }
        }
        return time;
    });

    if (currentMode === 'sleep') {
        // Heart Rate Chart
        charts.heartRate.data.labels = labels;
        charts.heartRate.data.datasets[0].data = dataBuffer.map(d => d.heart_rate_bpm);
        charts.heartRate.update('none');

        // Respiration Chart
        charts.respiration.data.labels = labels;
        charts.respiration.data.datasets[0].data = dataBuffer.map(d => d.respiration_rate);
        charts.respiration.update('none');

        // Presence Chart
        charts.presence.data.labels = labels;
        charts.presence.data.datasets[0].data = dataBuffer.map(d => d.human_presence);
        charts.presence.data.datasets[1].data = dataBuffer.map(d => d.human_movement);
        charts.presence.update('none');

        // Sleep Quality Chart
        charts.sleepQuality.data.labels = labels;
        charts.sleepQuality.data.datasets[0].data = dataBuffer.map(d => d.stats_sleep_quality_score || 0);
        charts.sleepQuality.update('none');
    } else {
        // Fall State Chart
        charts.fallState.data.labels = labels;
        charts.fallState.data.datasets[0].data = dataBuffer.map(d => d.fall_state);
        charts.fallState.update('none');

        // Motion Chart (with dual Y-axes)
        charts.motion.data.labels = labels;
        charts.motion.data.datasets[0].data = dataBuffer.map(d => d.human_existence);
        charts.motion.data.datasets[1].data = dataBuffer.map(d => d.motion_detected);
        charts.motion.data.datasets[2].data = dataBuffer.map(d => d.body_movement || 0);
        charts.motion.update('none');

        // Position Scatter Chart (convert cm to feet, skip 0,0 points)
        // Dataset 0 is the sensor (always at 0,0) - no need to update
        const filteredData = dataBuffer.filter(d => d.track_x > 0 || d.track_y > 0);
        const positionData = filteredData.map(d => ({
            x: d.track_x ? (d.track_x / 30.48) : 0,
            y: d.track_y ? (d.track_y / 30.48) : 0
        }));

        // Calculate dynamic Y-axis range based on actual data
        let maxY = 20;  // Default room size
        if (positionData.length > 0) {
            const dataMaxY = Math.max(...positionData.map(p => p.y));
            if (dataMaxY > 20) {
                maxY = Math.ceil(dataMaxY * 1.1);  // Add 10% padding
            }
        }

        // Update Y-axis scale dynamically
        charts.position.options.scales.y.max = maxY;

        // Adjust aspect ratio to maintain proportions (15' width : maxY height)
        charts.position.options.aspectRatio = 15 / maxY;

        // Dataset 1: Movement trail (line connecting all points)
        charts.position.data.datasets[1].data = positionData;

        // Dataset 2: Historical positions (small blue dots that fade with age)
        const historicalData = positionData.slice(0, -1);  // All except last
        charts.position.data.datasets[2].data = historicalData;

        // Make older dots smaller (gradient from 2 to 5 pixels)
        charts.position.data.datasets[2].pointRadius = historicalData.map((d, i) => {
            return 2 + (i / Math.max(1, historicalData.length - 1)) * 3;  // 2px → 5px
        });

        // Make older dots more transparent
        charts.position.data.datasets[2].backgroundColor = historicalData.map((d, i) => {
            const opacity = 0.2 + (i / Math.max(1, historicalData.length - 1)) * 0.4;  // 0.2 → 0.6
            return `rgba(99, 102, 241, ${opacity})`;
        });

        // Dataset 3: Current position (large green dot)
        if (positionData.length > 0) {
            const currentPos = positionData[positionData.length - 1];
            charts.position.data.datasets[3] = charts.position.data.datasets[3] || {
                label: 'Current Position',
                data: [],
                backgroundColor: 'rgba(34, 197, 94, 0.8)',  // Green
                borderColor: 'rgb(34, 197, 94)',
                pointStyle: 'circle',
                pointRadius: 10,
                borderWidth: 3,
                showLine: false
            };
            charts.position.data.datasets[3].data = [currentPos];
        }

        charts.position.update('none');

        // Residency Time Chart (only show when person is present AND static residency is active)
        charts.residency.data.labels = labels;
        charts.residency.data.datasets[0].data = dataBuffer.map(d => {
            // Only show residency time if person is detected AND static_residency state is active
            return (d.human_existence > 0 && d.static_residency > 0) ? (d.static_residency_time_sec || 0) : 0;
        });
        charts.residency.update('none');
    }
}

// Update status bar
function updateStatusBar(data) {
    document.getElementById('device-id').textContent = data.device_id || '--';
    document.getElementById('location').textContent = data.location || '--';

    // Use device_timestamp (exact reading time) if available, else created_at (server receive time)
    const timestamp = new Date(data.device_timestamp || data.created_at);
    document.getElementById('last-update').textContent = timestamp.toLocaleTimeString();
}

// Update connection status
function updateConnectionStatus(connected) {
    const statusElement = document.getElementById('connection-status');
    const dotElement = document.querySelector('.status-dot');

    if (connected) {
        statusElement.textContent = 'Connected';
        dotElement.style.background = '#10b981';
    } else {
        statusElement.textContent = 'Disconnected';
        dotElement.style.background = '#ef4444';
    }
}

// Check for alerts
function checkAlerts(data) {
    const alerts = [];

    if (currentMode === 'sleep') {
        // Sleep Mode alerts
        if (data.composite_apnea_events > 0) {
            alerts.push(`Apnea event detected! Count: ${data.composite_apnea_events}`);
        }

        if (data.abnormal_struggle > 0) {
            alerts.push('Abnormal struggle detected!');
        }

        if (data.in_bed === 0 && data.sleep_state > 0) {
            const now = new Date();
            const hour = now.getHours();
            if (hour >= 22 || hour <= 6) {
                alerts.push('Person out of bed during night hours');
            }
        }

        if (data.unattended_state > 0) {
            alerts.push('Person has left the monitored area');
        }
    } else {
        // Fall Detection alerts
        if (data.fall_state > 0) {
            alerts.push('🚨 FALL DETECTED! Immediate attention required!');
        }

        // Only alert about residency time if person is actually present
        if (data.human_existence > 0 && data.static_residency_time_sec > 30) {
            alerts.push(`Person has been on floor for ${data.static_residency_time_sec} seconds`);
        }

        // Only show fall duration if person is present and fall was detected
        if (data.human_existence > 0 && data.fall_time_sec > 0) {
            alerts.push(`Fall duration: ${data.fall_time_sec} seconds`);
        }
    }

    // Show alerts
    const alertBox = document.getElementById('alert-box');
    const alertMessage = document.getElementById('alert-message');

    if (alerts.length > 0) {
        alertMessage.textContent = alerts.join(' | ');
        alertBox.classList.add('active');
    } else {
        alertBox.classList.remove('active');
    }
}
