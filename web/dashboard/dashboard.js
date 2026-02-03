// Initialize Supabase client
const { createClient } = window.supabase;
const db = createClient(SUPABASE_CONFIG.url, SUPABASE_CONFIG.anonKey);

// Data storage
let dataBuffer = [];
let hourlyDataBuffer = [];  // 1-hour data buffer
let timeline12HourBuffer = [];  // 12-hour data buffer
let charts = {};
let currentMode = 'sleep'; // or 'fall_detection'
let modeDetected = false;  // Track if we've detected the mode from data
let lastDataTimestamp = null;  // Track last data received time

// Fetch current operational mode from database
async function fetchDeviceMode() {
    try {
        const { data, error } = await db
            .from('moveometers')
            .select('operational_mode')
            .eq('device_id', 'ESP32C6_001')
            .single();

        if (error) {
            console.error('Error fetching device mode:', error);
            return 'sleep'; // Default fallback
        }

        if (data && data.operational_mode) {
            console.log('Device mode from database:', data.operational_mode);
            return data.operational_mode;
        }

        return 'sleep'; // Default fallback
    } catch (err) {
        console.error('Exception fetching device mode:', err);
        return 'sleep'; // Default fallback
    }
}

// Initialize dashboard
document.addEventListener('DOMContentLoaded', async () => {
    console.log('Dashboard initializing...');

    // Fetch current device mode from database
    const deviceMode = await fetchDeviceMode();
    currentMode = deviceMode;
    modeDetected = true;

    // Update UI to match device mode
    document.getElementById('mode-sleep').classList.toggle('active', currentMode === 'sleep');
    document.getElementById('mode-fall').classList.toggle('active', currentMode === 'fall_detection');
    document.getElementById('sleep-metrics').style.display = currentMode === 'sleep' ? 'grid' : 'none';
    document.getElementById('fall-metrics').style.display = currentMode === 'fall_detection' ? 'grid' : 'none';
    document.getElementById('sleep-charts').style.display = currentMode === 'sleep' ? 'grid' : 'none';
    document.getElementById('fall-charts').style.display = currentMode === 'fall_detection' ? 'grid' : 'none';

    console.log(`Dashboard initialized in ${currentMode} mode`);

    // Initialize charts
    initializeCharts();

    // Load initial data
    await loadInitialData();

    // Load 1-hour historical data for hourly chart
    await loadHourlyData();

    // Load 12-hour historical data for timeline
    await load12HourData();

    // Set up real-time subscription
    setupRealtimeSubscription();

    // Set up periodic refresh as backup
    setInterval(loadLatestData, DASHBOARD_CONFIG.refreshInterval);

    // Check device online status every 5 seconds
    setInterval(checkDeviceOnlineStatus, 5000);
});

// Mode switching function
async function switchMode(mode) {
    // Confirm mode change since it affects device behavior
    const modeLabel = mode === 'sleep' ? 'Sleep Monitoring' : 'Fall Detection';
    if (!confirm(`Switch device to ${modeLabel} mode? This will reconfigure the sensor.`)) {
        return;
    }

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

    // Update operational mode in database
    try {
        const { error } = await db
            .from('moveometers')
            .update({
                operational_mode: mode,
                config_updated: true  // Trigger immediate sync on device
            })
            .eq('device_id', 'ESP32C6_001');

        if (error) {
            console.error('Error updating mode:', error);
            alert('❌ Failed to update device mode. Please try again.');
        } else {
            console.log(`Mode changed to ${mode}, device will sync within 5 seconds`);
        }
    } catch (err) {
        console.error('Exception updating mode:', err);
        alert('❌ Failed to update device mode. Please try again.');
    }

    // Clear and reload data for new mode
    dataBuffer = [];
    hourlyDataBuffer = [];
    timeline12HourBuffer = [];
    loadInitialData();
    loadHourlyData();
    load12HourData();
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

    // Vitals Chart (Heart Rate + Respiration)
    charts.vitals = new Chart(document.getElementById('vitalsChart'), {
        type: 'line',
        data: {
            labels: [],
            datasets: [
                {
                    label: 'Heart Rate (bpm)',
                    data: [],
                    borderColor: 'rgb(255, 99, 132)',
                    backgroundColor: 'rgba(255, 99, 132, 0.1)',
                    tension: 0.4,
                    yAxisID: 'y'
                },
                {
                    label: 'Respiration (/min)',
                    data: [],
                    borderColor: 'rgb(54, 162, 235)',
                    backgroundColor: 'rgba(54, 162, 235, 0.1)',
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
                    title: { display: true, text: 'Heart Rate (bpm)' }
                },
                y1: {
                    type: 'linear',
                    display: true,
                    position: 'right',
                    title: { display: true, text: 'Respiration (/min)' },
                    grid: { drawOnChartArea: false }
                }
            }
        }
    });

    // Sleep State Chart
    charts.sleepState = new Chart(document.getElementById('sleepStateChart'), {
        type: 'line',
        data: {
            labels: [],
            datasets: [
                {
                    label: 'Sleep State',
                    data: [],
                    borderColor: 'rgb(153, 102, 255)',
                    backgroundColor: 'rgba(153, 102, 255, 0.1)',
                    tension: 0.4,
                    stepped: true
                },
                {
                    label: 'In Bed',
                    data: [],
                    borderColor: 'rgb(75, 192, 192)',
                    backgroundColor: 'rgba(75, 192, 192, 0.1)',
                    tension: 0.4,
                    stepped: true
                }
            ]
        },
        options: chartOptions
    });

    // Sleep Quality Chart
    charts.sleepQuality = new Chart(document.getElementById('sleepQualityChart'), {
        type: 'line',
        data: {
            labels: [],
            datasets: [{
                label: 'Sleep Quality Score',
                data: [],
                borderColor: 'rgb(139, 92, 246)',
                backgroundColor: 'rgba(139, 92, 246, 0.2)',
                tension: 0.4,
                fill: true
            }]
        },
        options: {
            ...chartOptions,
            scales: {
                y: { beginAtZero: true, max: 100 }
            }
        }
    });

    // Sleep Phases Chart
    charts.sleepPhases = new Chart(document.getElementById('sleepPhasesChart'), {
        type: 'line',
        data: {
            labels: [],
            datasets: [
                {
                    label: 'Light Sleep %',
                    data: [],
                    borderColor: 'rgb(96, 165, 250)',
                    backgroundColor: 'rgba(96, 165, 250, 0.2)',
                    tension: 0.4,
                    fill: true
                },
                {
                    label: 'Deep Sleep %',
                    data: [],
                    borderColor: 'rgb(99, 102, 241)',
                    backgroundColor: 'rgba(99, 102, 241, 0.2)',
                    tension: 0.4,
                    fill: true
                }
            ]
        },
        options: {
            ...chartOptions,
            scales: {
                y: { beginAtZero: true, max: 100, title: { display: true, text: 'Percentage' } }
            }
        }
    });

    // Body Movement Chart
    charts.bodyMovement = new Chart(document.getElementById('bodyMovementChart'), {
        type: 'bar',
        data: {
            labels: [],
            datasets: [
                {
                    label: 'Large Body Movement',
                    data: [],
                    backgroundColor: 'rgba(239, 68, 68, 0.6)',
                    borderColor: 'rgb(239, 68, 68)',
                    borderWidth: 1
                },
                {
                    label: 'Minor Body Movement',
                    data: [],
                    backgroundColor: 'rgba(251, 146, 60, 0.6)',
                    borderColor: 'rgb(251, 146, 60)',
                    borderWidth: 1
                }
            ]
        },
        options: chartOptions
    });

    // Apnea & Abnormal Chart
    charts.apnea = new Chart(document.getElementById('apneaChart'), {
        type: 'bar',
        data: {
            labels: [],
            datasets: [
                {
                    label: 'Apnea Events',
                    data: [],
                    backgroundColor: 'rgba(220, 38, 38, 0.6)',
                    borderColor: 'rgb(220, 38, 38)',
                    borderWidth: 1
                },
                {
                    label: 'Abnormal Struggle',
                    data: [],
                    backgroundColor: 'rgba(245, 158, 11, 0.6)',
                    borderColor: 'rgb(245, 158, 11)',
                    borderWidth: 1
                }
            ]
        },
        options: chartOptions
    });

    // Sleep Duration Chart
    charts.sleepDuration = new Chart(document.getElementById('sleepDurationChart'), {
        type: 'bar',
        data: {
            labels: [],
            datasets: [
                {
                    label: 'Sleep Time (min)',
                    data: [],
                    backgroundColor: 'rgba(59, 130, 246, 0.6)',
                    borderColor: 'rgb(59, 130, 246)',
                    borderWidth: 1
                },
                {
                    label: 'Wake Duration (min)',
                    data: [],
                    backgroundColor: 'rgba(251, 191, 36, 0.6)',
                    borderColor: 'rgb(251, 191, 36)',
                    borderWidth: 1
                }
            ]
        },
        options: chartOptions
    });

    // Turnover Chart
    charts.turnover = new Chart(document.getElementById('turnoverChart'), {
        type: 'bar',
        data: {
            labels: [],
            datasets: [{
                label: 'Turnover Count',
                data: [],
                backgroundColor: 'rgba(168, 85, 247, 0.6)',
                borderColor: 'rgb(168, 85, 247)',
                borderWidth: 1
            }]
        },
        options: chartOptions
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
                    label: 'Motion Intensity (0-5)',
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
                    max: 5,
                    title: {
                        display: true,
                        text: 'Presence & Motion (0-5)'
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

    // Motion Chart - 1 Hour Timeline
    charts.motionHour = new Chart(document.getElementById('motionHourChart'), {
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
                    label: 'Motion Intensity (0-5)',
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
                    max: 5,
                    title: {
                        display: true,
                        text: 'Presence & Motion (0-5)'
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

    // 12-Hour Timeline (works for both modes)
    charts.timeline12Hour = new Chart(document.getElementById('timeline12Hour'), {
        type: 'line',
        data: {
            labels: [],
            datasets: [
                {
                    label: 'Activity Level',
                    data: [],
                    borderColor: 'rgb(102, 126, 234)',
                    backgroundColor: 'rgba(102, 126, 234, 0.2)',
                    tension: 0.3,
                    fill: true,
                    pointRadius: 0,
                    borderWidth: 2
                }
            ]
        },
        options: {
            responsive: true,
            maintainAspectRatio: true,
            animation: {
                duration: 300
            },
            scales: {
                x: {
                    ticks: {
                        maxTicksLimit: 24,
                        autoSkip: true
                    }
                },
                y: {
                    beginAtZero: true,
                    title: {
                        display: true,
                        text: 'Activity Level'
                    }
                }
            },
            plugins: {
                legend: {
                    display: true,
                    position: 'top'
                },
                tooltip: {
                    mode: 'index',
                    intersect: false
                }
            }
        }
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

// Load 1 hour of historical data for hourly chart
async function loadHourlyData() {
    try {
        const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000).toISOString();

        let query = db
            .from(SUPABASE_CONFIG.table)
            .select('*')
            .gte('created_at', oneHourAgo)
            .order('created_at', { ascending: true });

        if (DASHBOARD_CONFIG.deviceId) {
            query = query.eq('device_id', DASHBOARD_CONFIG.deviceId);
        }

        // Filter by current mode
        if (currentMode) {
            query = query.eq('sensor_mode', currentMode);
        }

        const { data, error } = await query;

        if (error) throw error;

        if (data && data.length > 0) {
            hourlyDataBuffer = data;
            updateHourlyChart();
            console.log(`Loaded ${hourlyDataBuffer.length} data points for 1-hour chart`);
        }
    } catch (error) {
        console.error('Error loading hourly data:', error);
    }
}

// Load 12 hours of historical data for timeline
async function load12HourData() {
    try {
        const twelveHoursAgo = new Date(Date.now() - 12 * 60 * 60 * 1000).toISOString();

        let query = db
            .from(SUPABASE_CONFIG.table)
            .select('*')
            .gte('created_at', twelveHoursAgo)
            .order('created_at', { ascending: true });

        if (DASHBOARD_CONFIG.deviceId) {
            query = query.eq('device_id', DASHBOARD_CONFIG.deviceId);
        }

        // Filter by current mode
        if (currentMode) {
            query = query.eq('sensor_mode', currentMode);
        }

        const { data, error } = await query;

        if (error) throw error;

        if (data && data.length > 0) {
            timeline12HourBuffer = data;
            update12HourTimeline();
            console.log(`Loaded ${timeline12HourBuffer.length} data points for 12-hour timeline`);
        }
    } catch (error) {
        console.error('Error loading 12-hour data:', error);
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

    // Update last data timestamp for online status
    lastDataTimestamp = newData.device_timestamp || newData.created_at;
    checkDeviceOnlineStatus();

    // Add to buffer
    dataBuffer.push(newData);

    // Keep only the last N points
    if (dataBuffer.length > DASHBOARD_CONFIG.maxDataPoints) {
        dataBuffer.shift();
    }

    // Add to hourly buffer
    hourlyDataBuffer.push(newData);

    // Keep only data from last hour
    const oneHourAgo = Date.now() - 60 * 60 * 1000;
    hourlyDataBuffer = hourlyDataBuffer.filter(d => {
        const timestamp = new Date(d.device_timestamp || d.created_at).getTime();
        return timestamp >= oneHourAgo;
    });

    // Update hourly chart
    if (currentMode === 'fall_detection') {
        updateHourlyChart();
    }

    // Add to 12-hour timeline buffer
    timeline12HourBuffer.push(newData);

    // Keep only data from last 12 hours
    const twelveHoursAgo = Date.now() - 12 * 60 * 60 * 1000;
    timeline12HourBuffer = timeline12HourBuffer.filter(d => {
        const timestamp = new Date(d.device_timestamp || d.created_at).getTime();
        return timestamp >= twelveHoursAgo;
    });

    // Update 12-hour timeline
    update12HourTimeline();

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
        document.getElementById('heart-rate').textContent = data.heart_rate_bpm || data.composite_avg_heartbeat || '--';
        document.getElementById('respiration').textContent = data.respiration_rate || data.composite_avg_respiration || '--';

        const sleepStates = ['Unknown', 'Awake', 'Light Sleep', 'Deep Sleep', 'REM'];
        document.getElementById('sleep-state').textContent = sleepStates[data.sleep_state] || data.sleep_state || '--';
        document.getElementById('in-bed').textContent = data.in_bed ? 'Yes' : 'No';
        document.getElementById('sleep-quality').textContent = data.stats_sleep_quality_score || '--';
        document.getElementById('sleep-time').textContent = data.stats_sleep_time_min || '--';
        document.getElementById('apnea').textContent = data.composite_apnea_events || '0';
        document.getElementById('turnover').textContent = data.composite_turn_over_count || '0';
        document.getElementById('sleep-body-movement').textContent = data.body_movement || '0';
    } else {
        // Fall Detection metrics
        document.getElementById('fall-state').textContent = data.fall_state ? '🚨 YES' : '✅ No';
        document.getElementById('existence').textContent = data.human_existence ? 'Yes' : 'No';
        document.getElementById('motion').textContent = data.motion_detected > 0 ? `Yes (${data.motion_detected})` : 'No';
        document.getElementById('body-movement').textContent = data.body_movement || '0';

        // Only show residency time if person is present
        const residencyTime = (data.human_existence > 0) ? (data.static_residency_time_sec || 0) : 0;
        document.getElementById('residency-time').textContent = residencyTime;
    }
}

// Update hourly chart
function updateHourlyChart() {
    if (hourlyDataBuffer.length === 0 || currentMode !== 'fall_detection') return;

    const labels = hourlyDataBuffer.map((d, i) => {
        const timestamp = d.device_timestamp || d.created_at;
        const date = new Date(timestamp);
        return date.toLocaleTimeString('en-US', {
            hour: '2-digit',
            minute: '2-digit',
            hour12: false
        });
    });

    charts.motionHour.data.labels = labels;
    charts.motionHour.data.datasets[0].data = hourlyDataBuffer.map(d => d.human_existence);
    charts.motionHour.data.datasets[1].data = hourlyDataBuffer.map(d => d.motion_detected);
    charts.motionHour.data.datasets[2].data = hourlyDataBuffer.map(d => d.body_movement || 0);
    charts.motionHour.update('none');
}

// Update 12-hour timeline
function update12HourTimeline() {
    if (timeline12HourBuffer.length === 0) return;

    const labels = timeline12HourBuffer.map((d, i) => {
        const timestamp = d.device_timestamp || d.created_at;
        const date = new Date(timestamp);
        return date.toLocaleTimeString('en-US', {
            hour: '2-digit',
            minute: '2-digit',
            hour12: true
        });
    });

    // Calculate activity level based on mode
    let activityData;
    if (currentMode === 'sleep') {
        // For sleep mode: combine body movement, heart rate variability, and turnover
        activityData = timeline12HourBuffer.map(d => {
            const bodyMovement = d.body_movement || 0;
            const heartRate = d.heart_rate_bpm || d.composite_avg_heartbeat || 0;
            const turnover = d.composite_turn_over_count || 0;
            // Normalize to 0-100 scale
            return Math.min(100, bodyMovement + (turnover * 10) + (heartRate > 0 ? 10 : 0));
        });
    } else {
        // For fall detection: combine existence, motion, and body movement
        activityData = timeline12HourBuffer.map(d => {
            const existence = (d.human_existence || 0) * 20;
            const motion = (d.motion_detected || 0) * 10;
            const bodyMovement = d.body_movement || 0;
            return existence + motion + bodyMovement;
        });
    }

    charts.timeline12Hour.data.labels = labels;
    charts.timeline12Hour.data.datasets[0].data = activityData;
    charts.timeline12Hour.update('none');
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
        // Vitals Chart (Heart Rate + Respiration)
        charts.vitals.data.labels = labels;
        charts.vitals.data.datasets[0].data = dataBuffer.map(d => d.heart_rate_bpm || d.composite_avg_heartbeat || 0);
        charts.vitals.data.datasets[1].data = dataBuffer.map(d => d.respiration_rate || d.composite_avg_respiration || 0);
        charts.vitals.update('none');

        // Sleep State Chart
        charts.sleepState.data.labels = labels;
        charts.sleepState.data.datasets[0].data = dataBuffer.map(d => d.sleep_state || 0);
        charts.sleepState.data.datasets[1].data = dataBuffer.map(d => d.in_bed || 0);
        charts.sleepState.update('none');

        // Sleep Quality Chart
        charts.sleepQuality.data.labels = labels;
        charts.sleepQuality.data.datasets[0].data = dataBuffer.map(d => d.stats_sleep_quality_score || 0);
        charts.sleepQuality.update('none');

        // Sleep Phases Chart
        charts.sleepPhases.data.labels = labels;
        charts.sleepPhases.data.datasets[0].data = dataBuffer.map(d => d.stats_light_sleep_pct || 0);
        charts.sleepPhases.data.datasets[1].data = dataBuffer.map(d => d.stats_deep_sleep_pct || 0);
        charts.sleepPhases.update('none');

        // Body Movement Chart
        charts.bodyMovement.data.labels = labels;
        charts.bodyMovement.data.datasets[0].data = dataBuffer.map(d => d.stats_large_body_movement || 0);
        charts.bodyMovement.data.datasets[1].data = dataBuffer.map(d => d.stats_minor_body_movement || 0);
        charts.bodyMovement.update('none');

        // Apnea & Abnormal Chart
        charts.apnea.data.labels = labels;
        charts.apnea.data.datasets[0].data = dataBuffer.map(d => d.composite_apnea_events || 0);
        charts.apnea.data.datasets[1].data = dataBuffer.map(d => d.abnormal_struggle || 0);
        charts.apnea.update('none');

        // Sleep Duration Chart
        charts.sleepDuration.data.labels = labels;
        charts.sleepDuration.data.datasets[0].data = dataBuffer.map(d => d.stats_sleep_time_min || 0);
        charts.sleepDuration.data.datasets[1].data = dataBuffer.map(d => d.stats_wake_duration || 0);
        charts.sleepDuration.update('none');

        // Turnover Chart
        charts.turnover.data.labels = labels;
        charts.turnover.data.datasets[0].data = dataBuffer.map(d => d.composite_turn_over_count || 0);
        charts.turnover.update('none');
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
    const now = new Date();
    const secondsAgo = Math.round((now - timestamp) / 1000);

    let timeText = timestamp.toLocaleTimeString();
    if (secondsAgo < 60) {
        timeText += ` (${secondsAgo}s ago)`;
    } else if (secondsAgo < 3600) {
        timeText += ` (${Math.round(secondsAgo / 60)}m ago)`;
    }

    document.getElementById('last-update').textContent = timeText;
}

// Check if device is online (received data within last 30 seconds)
function checkDeviceOnlineStatus() {
    const statusElement = document.getElementById('connection-status');
    const dotElement = document.querySelector('.status-dot');

    if (!lastDataTimestamp) {
        statusElement.textContent = 'Waiting for data...';
        dotElement.style.background = '#f59e0b'; // Orange
        return;
    }

    const now = new Date();
    const lastData = new Date(lastDataTimestamp);
    const secondsSinceLastData = (now - lastData) / 1000;

    // Device is online if data received within last 30 seconds
    const ONLINE_THRESHOLD = 30; // seconds

    if (secondsSinceLastData <= ONLINE_THRESHOLD) {
        statusElement.textContent = 'Online';
        dotElement.style.background = '#10b981'; // Green
    } else if (secondsSinceLastData <= 60) {
        statusElement.textContent = `Stale (${Math.round(secondsSinceLastData)}s ago)`;
        dotElement.style.background = '#f59e0b'; // Orange
    } else {
        statusElement.textContent = 'Offline';
        dotElement.style.background = '#ef4444'; // Red
    }
}

// Update connection status (legacy function, now uses checkDeviceOnlineStatus)
function updateConnectionStatus(connected) {
    checkDeviceOnlineStatus();
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

// ========================================
// Settings Panel Functions
// ========================================

// Toggle settings panel visibility
function toggleSettings() {
    const content = document.getElementById('settings-content');
    const toggle = document.getElementById('settings-toggle');

    if (content.classList.contains('hidden')) {
        content.classList.remove('hidden');
        toggle.classList.remove('collapsed');
    } else {
        content.classList.add('hidden');
        toggle.classList.add('collapsed');
    }
}

// Initialize slider event listeners
document.addEventListener('DOMContentLoaded', () => {
    // Sampling rate sliders
    setupSlider('fall-interval', 'fall-interval-value');
    setupSlider('sleep-interval', 'sleep-interval-value');
    setupSlider('config-check', 'config-check-value');

    // OTA check slider (special handling - converts minutes to/from milliseconds)
    const otaSlider = document.getElementById('ota-check-slider');
    const otaValue = document.getElementById('ota-check-value');
    if (otaSlider && otaValue) {
        otaSlider.addEventListener('input', (e) => {
            otaValue.textContent = e.target.value;
        });
    }

    // General settings sliders
    setupSlider('install-height', 'install-height-value');
    setupSlider('install-angle', 'install-angle-value');
    setupSlider('room-width', 'room-width-value');
    setupSlider('room-length', 'room-length-value');

    // Fall detection sliders
    setupSlider('fall-sensitivity', 'fall-sensitivity-value');
    setupSlider('fall-break-height', 'fall-break-height-value');
    setupSlider('seated-distance', 'seated-distance-value');
    setupSlider('motion-distance', 'motion-distance-value');

    // Sleep mode sliders
    setupSlider('sleep-distance', 'sleep-distance-value');
    setupSlider('breathing-min', 'breathing-min-value');
    setupSlider('breathing-max', 'breathing-max-value');
    setupSlider('heart-min', 'heart-min-value');
    setupSlider('heart-max', 'heart-max-value');
    setupSlider('apnea-threshold', 'apnea-threshold-value');

    // Load current settings from database
    loadCurrentSettings();
});

// Setup slider value update
function setupSlider(sliderId, valueId) {
    const slider = document.getElementById(`${sliderId}-slider`);
    const valueDisplay = document.getElementById(valueId);

    if (slider && valueDisplay) {
        slider.addEventListener('input', (e) => {
            valueDisplay.textContent = e.target.value;
        });
    }
}

// Load current settings from database
async function loadCurrentSettings() {
    try {
        const { data, error } = await db
            .from('moveometers')
            .select('*')
            .eq('device_id', 'ESP32C6_001')
            .single();

        if (error) {
            console.error('Error loading settings:', error);
            return;
        }

        if (data) {
            // Sampling rate settings
            updateSlider('fall-interval', data.fall_detection_interval_ms || 20000);
            updateSlider('sleep-interval', data.sleep_mode_interval_ms || 20000);
            updateSlider('config-check', data.config_check_interval_ms || 20000);
            updateSlider('ota-check', Math.round((data.ota_check_interval_ms || 3600000) / 60000));  // Convert ms to minutes

            // General settings
            updateSlider('install-height', Math.round((data.install_height_cm || 250) / 30.48 * 10) / 10);  // Convert cm to feet
            updateSlider('install-angle', data.install_angle || 0);
            updateSlider('room-width', data.room_width_ft || 15.0);
            updateSlider('room-length', data.room_length_ft || 20.0);
            document.getElementById('position-tracking-toggle').checked = data.position_tracking_enabled !== false;

            // Fall detection settings
            updateSlider('fall-sensitivity', data.fall_sensitivity || 5);
            updateSlider('fall-break-height', data.fall_break_height_cm || 100);
            updateSlider('seated-distance', data.seated_distance_threshold_cm || 100);
            updateSlider('motion-distance', data.motion_distance_threshold_cm || 150);

            // Sleep mode settings
            updateSlider('sleep-distance', data.sleep_detection_distance_cm || 250);
            updateSlider('breathing-min', data.breathing_alert_min || 10);
            updateSlider('breathing-max', data.breathing_alert_max || 25);
            updateSlider('heart-min', data.heart_rate_alert_min || 60);
            updateSlider('heart-max', data.heart_rate_alert_max || 100);
            updateSlider('apnea-threshold', data.apnea_alert_threshold || 3);

            console.log('Settings loaded successfully');
        }
    } catch (err) {
        console.error('Exception loading settings:', err);
    }
}

// Update slider value programmatically
function updateSlider(sliderId, value) {
    const slider = document.getElementById(`${sliderId}-slider`);
    const valueDisplay = document.getElementById(`${sliderId}-value`);

    if (slider && valueDisplay) {
        slider.value = value;
        valueDisplay.textContent = value;
    }
}

// Send command to device
async function sendCommand(command) {
    const commandLabels = {
        'reconfigure': 'Reconfigure Sensor',
        'reset_sensor': 'Hardware Reset Sensor',
        'reboot': 'Reboot ESP32'
    };

    const label = commandLabels[command] || command;

    if (!confirm(`Send command: ${label}?\n\nThe device will execute this within 5 seconds.`)) {
        return;
    }

    try {
        const { error } = await db
            .from('moveometers')
            .update({
                pending_command: command,
                command_timestamp: new Date().toISOString()
            })
            .eq('device_id', 'ESP32C6_001');

        if (error) {
            console.error('Error sending command:', error);
            alert('❌ Failed to send command. Please try again.');
        } else {
            console.log(`Command sent: ${command}`);
            alert(`✅ Command sent! Device will execute "${label}" within 5 seconds.`);
        }
    } catch (err) {
        console.error('Exception sending command:', err);
        alert('❌ Failed to send command. Please try again.');
    }
}

// Reset all settings to factory defaults
function resetToDefaults() {
    if (!confirm('Reset all settings to factory defaults? This will affect the device immediately after saving.')) {
        return;
    }

    // Factory default values
    const defaults = {
        'fall-interval': 20000,
        'sleep-interval': 20000,
        'config-check': 20000,
        'ota-check': 60,  // minutes
        'install-height': 8.2,  // feet
        'install-angle': 0,
        'room-width': 15.0,
        'room-length': 20.0,
        'fall-sensitivity': 5,
        'fall-break-height': 100,
        'seated-distance': 100,
        'motion-distance': 150,
        'sleep-distance': 250,
        'breathing-min': 10,
        'breathing-max': 25,
        'heart-min': 60,
        'heart-max': 100,
        'apnea-threshold': 3
    };

    // Update all sliders
    for (const [id, value] of Object.entries(defaults)) {
        updateSlider(id, value);
    }

    // Reset position tracking toggle
    document.getElementById('position-tracking-toggle').checked = true;

    console.log('All settings reset to factory defaults');
    alert('✅ Settings reset to factory defaults. Click "Save Settings" to apply to device.');
}

// Save settings to database
async function saveSettings() {
    const button = document.querySelector('.save-button');
    button.disabled = true;
    button.textContent = '⏳ Saving...';

    try {
        const settings = {
            // Sampling rate settings
            fall_detection_interval_ms: parseInt(document.getElementById('fall-interval-slider').value),
            sleep_mode_interval_ms: parseInt(document.getElementById('sleep-interval-slider').value),
            config_check_interval_ms: parseInt(document.getElementById('config-check-slider').value),
            ota_check_interval_ms: parseInt(document.getElementById('ota-check-slider').value) * 60000,  // Convert minutes to ms

            // General settings
            install_height_cm: Math.round(parseFloat(document.getElementById('install-height-slider').value) * 30.48),  // Convert feet to cm
            install_angle: parseInt(document.getElementById('install-angle-slider').value),
            room_width_ft: parseFloat(document.getElementById('room-width-slider').value),
            room_length_ft: parseFloat(document.getElementById('room-length-slider').value),
            position_tracking_enabled: document.getElementById('position-tracking-toggle').checked,

            // Fall detection settings
            fall_sensitivity: parseInt(document.getElementById('fall-sensitivity-slider').value),
            fall_break_height_cm: parseInt(document.getElementById('fall-break-height-slider').value),
            seated_distance_threshold_cm: parseInt(document.getElementById('seated-distance-slider').value),
            motion_distance_threshold_cm: parseInt(document.getElementById('motion-distance-slider').value),

            // Sleep mode settings
            sleep_detection_distance_cm: parseInt(document.getElementById('sleep-distance-slider').value),
            breathing_alert_min: parseInt(document.getElementById('breathing-min-slider').value),
            breathing_alert_max: parseInt(document.getElementById('breathing-max-slider').value),
            heart_rate_alert_min: parseInt(document.getElementById('heart-min-slider').value),
            heart_rate_alert_max: parseInt(document.getElementById('heart-max-slider').value),
            apnea_alert_threshold: parseInt(document.getElementById('apnea-threshold-slider').value),

            // Trigger immediate config sync on device
            config_updated: true
        };

        const { error } = await db
            .from('moveometers')
            .update(settings)
            .eq('device_id', 'ESP32C6_001');

        if (error) {
            console.error('Error saving settings:', error);
            button.textContent = '❌ Save Failed';
            setTimeout(() => {
                button.textContent = '💾 Save Settings to Device';
                button.disabled = false;
            }, 2000);
        } else {
            console.log('Settings saved successfully');
            button.textContent = '✅ Saved!';
            setTimeout(() => {
                button.textContent = '💾 Save Settings to Device';
                button.disabled = false;
            }, 2000);
        }
    } catch (err) {
        console.error('Exception saving settings:', err);
        button.textContent = '❌ Save Failed';
        setTimeout(() => {
            button.textContent = '💾 Save Settings to Device';
            button.disabled = false;
        }, 2000);
    }
}
