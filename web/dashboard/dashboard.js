// Dashboard version
const DASHBOARD_VERSION = '2.1.4';

// Use shared Supabase client (initialized in config.js)
const db = getSupabaseClient();

// Data storage
let dataBuffer = [];
let hourlyDataBuffer = [];  // 1-hour data buffer
let timeline12HourBuffer = [];  // 12-hour data buffer
let timeline24HourBuffer = [];  // 24-hour data buffer
let userAnnotations = [];  // User-created annotations
let charts = {};
let currentMode = 'sleep'; // or 'fall_detection'
let modeDetected = false;  // Track if we've detected the mode from data
let lastDataTimestamp = null;  // Track last data received time
let deviceOnlineState = null;  // Track device state to prevent flickering (null, 'online', 'stale', 'offline')

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

// Check if user has access to any devices
async function checkDeviceAccess() {
    try {
        const { data: devices, error } = await db
            .from('moveometers')
            .select('device_id')
            .limit(1);

        if (error) {
            console.error('Error checking device access:', error);
            return false;
        }

        return devices && devices.length > 0;
    } catch (err) {
        console.error('Exception checking device access:', err);
        return false;
    }
}

// Show no devices message
function showNoDevicesMessage() {
    // Hide all dashboard content
    document.querySelector('.mode-selector').style.display = 'none';
    document.querySelector('.settings-panel').style.display = 'none';
    document.getElementById('sleep-metrics').style.display = 'none';
    document.getElementById('fall-metrics').style.display = 'none';
    document.getElementById('sleep-charts').style.display = 'none';
    document.getElementById('fall-charts').style.display = 'none';
    document.querySelectorAll('.chart-card.full-width').forEach(card => card.style.display = 'none');
    document.querySelector('.add-annotation-btn').style.display = 'none';

    // Create and show no devices message
    const container = document.querySelector('.container');
    const messageDiv = document.createElement('div');
    messageDiv.style.cssText = `
        background: white;
        border-radius: 10px;
        padding: 60px 40px;
        text-align: center;
        box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
        margin-top: 40px;
    `;
    messageDiv.innerHTML = `
        <div style="font-size: 64px; margin-bottom: 20px;">📱</div>
        <h2 style="color: #667eea; margin-bottom: 15px;">No moveOmeters Assigned</h2>
        <p style="color: #666; font-size: 16px; margin-bottom: 30px; max-width: 500px; margin-left: auto; margin-right: auto;">
            You don't have access to any moveOmeter devices yet.
            Contact your administrator to get device access assigned to your account.
        </p>
        <button class="btn btn-primary" style="opacity: 0.5; cursor: not-allowed;" disabled>
            + Add moveOmeter (Coming Soon)
        </button>
    `;

    // Insert after header
    const header = document.querySelector('.header');
    header.insertAdjacentElement('afterend', messageDiv);
}

// Initialize dashboard
document.addEventListener('DOMContentLoaded', async () => {
    console.log(`%c🚀 moveOmeter Dashboard v${DASHBOARD_VERSION}`, 'font-size: 16px; font-weight: bold; color: #667eea;');

    // Check if user has device access
    const hasDeviceAccess = await checkDeviceAccess();
    if (!hasDeviceAccess) {
        console.log('No device access - showing message');
        showNoDevicesMessage();
        return; // Stop dashboard initialization
    }

    // Fetch current device mode from database
    const deviceMode = await fetchDeviceMode();
    currentMode = deviceMode;
    modeDetected = true;

    // Update UI to match device mode
    document.getElementById('mode-sleep').classList.toggle('active', currentMode === 'sleep');
    document.getElementById('mode-fall').classList.toggle('active', currentMode === 'fall_detection');

    // Show/hide charts based on mode
    document.getElementById('sleep-charts').style.display = currentMode === 'sleep' ? 'grid' : 'none';
    document.getElementById('fall-charts').style.display = currentMode === 'fall_detection' ? 'grid' : 'none';

    // Metrics visibility will be controlled by checkDeviceOnlineStatus()
    // Initially hide until we get data
    document.getElementById('sleep-metrics').style.display = 'none';
    document.getElementById('fall-metrics').style.display = 'none';

    console.log(`Dashboard initialized in ${currentMode} mode`);

    // Initialize charts
    initializeCharts();

    // Load initial data
    await loadInitialData();

    // Load 1-hour historical data for hourly chart
    await loadHourlyData();

    // Load 12-hour historical data for timeline
    await load12HourData();

    // Load 24-hour historical data for timeline
    await load24HourData();

    // Load user annotations
    await loadUserAnnotations();

    // Set up real-time subscription
    setupRealtimeSubscription();

    // Set up periodic refresh as backup
    setInterval(loadLatestData, DASHBOARD_CONFIG.refreshInterval);

    // Refresh timeline charts every 2 minutes to ensure current data
    setInterval(async () => {
        console.log('🔄 Auto-refreshing timeline charts...');
        await load12HourData();
        await load24HourData();
    }, 2 * 60 * 1000); // Every 2 minutes

    // Check device online status every 2 seconds
    setInterval(checkDeviceOnlineStatus, 2000);
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

    // Show/hide charts (charts stay visible)
    document.getElementById('sleep-charts').style.display = mode === 'sleep' ? 'grid' : 'none';
    document.getElementById('fall-charts').style.display = mode === 'fall_detection' ? 'grid' : 'none';

    // Metrics visibility is controlled by checkDeviceOnlineStatus()
    // Call it now to update based on current online status
    checkDeviceOnlineStatus();

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

    // Reload all historical data
    await loadInitialData();
    await loadHourlyData();
    await load12HourData();
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
            datasets: [
                {
                    label: 'Existence (0/1)',
                    data: [],
                    borderColor: 'rgb(34, 197, 94)',
                    backgroundColor: 'rgba(34, 197, 94, 0.1)',
                    tension: 0.4,
                    pointRadius: 0,
                    borderWidth: 2,
                    yAxisID: 'y'
                },
                {
                    label: 'Motion Intensity (0-5)',
                    data: [],
                    borderColor: 'rgb(251, 146, 60)',
                    backgroundColor: 'rgba(251, 146, 60, 0.1)',
                    tension: 0.4,
                    pointRadius: 0,
                    borderWidth: 2,
                    yAxisID: 'y'
                },
                {
                    label: 'Body Movement (0-100)',
                    data: [],
                    borderColor: 'rgb(139, 92, 246)',
                    backgroundColor: 'rgba(139, 92, 246, 0.1)',
                    tension: 0.4,
                    pointRadius: 0,
                    borderWidth: 3,
                    yAxisID: 'y1'
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
                    type: 'time',
                    time: {
                        unit: 'minute',
                        displayFormats: {
                            minute: 'h:mm a'
                        },
                        tooltipFormat: 'h:mm a'
                    },
                    ticks: {
                        maxTicksLimit: 12,
                        autoSkip: true
                    },
                    title: {
                        display: true,
                        text: 'Time (Last 1 Hour)'
                    }
                },
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

    // 12-Hour Timeline (works for both modes)
    charts.timeline12Hour = new Chart(document.getElementById('timeline12Hour'), {
        type: 'line',
        data: {
            datasets: [
                {
                    label: 'Existence (0/1)',
                    data: [],
                    borderColor: 'rgb(34, 197, 94)',
                    backgroundColor: 'rgba(34, 197, 94, 0.1)',
                    tension: 0.1,
                    fill: false,
                    pointRadius: 0,
                    borderWidth: 2,
                    spanGaps: false,
                    yAxisID: 'y'
                },
                {
                    label: 'Motion (0-5)',
                    data: [],
                    borderColor: 'rgb(251, 146, 60)',
                    backgroundColor: 'rgba(251, 146, 60, 0.1)',
                    tension: 0.1,
                    fill: false,
                    pointRadius: 0,
                    borderWidth: 2,
                    spanGaps: false,
                    yAxisID: 'y'
                },
                {
                    label: 'Body Movement (0-100)',
                    data: [],
                    borderColor: 'rgb(139, 92, 246)',
                    backgroundColor: 'rgba(139, 92, 246, 0.1)',
                    tension: 0.1,
                    fill: false,
                    pointRadius: 0,
                    borderWidth: 3,
                    spanGaps: false,
                    yAxisID: 'y1'
                },
                {
                    label: 'Device Status (1=Online, 2=Offline)',
                    data: [],
                    borderColor: 'rgb(251, 191, 36)',
                    backgroundColor: 'rgba(251, 191, 36, 0.1)',
                    tension: 0,
                    fill: false,
                    pointRadius: 0,
                    borderWidth: 2,
                    borderDash: [5, 5],
                    spanGaps: false,
                    yAxisID: 'y'
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
                    type: 'time',
                    time: {
                        unit: 'hour',
                        displayFormats: {
                            hour: 'h:mm a'
                        },
                        tooltipFormat: 'MMM d, h:mm a'
                    },
                    ticks: {
                        maxTicksLimit: 12,
                        autoSkip: true,
                        maxRotation: 45,
                        minRotation: 45
                    },
                    title: {
                        display: true,
                        text: 'Time (Last 12 Hours)'
                    }
                },
                y: {
                    type: 'linear',
                    position: 'left',
                    beginAtZero: true,
                    max: 5,
                    title: {
                        display: true,
                        text: 'Existence / Motion'
                    }
                },
                y1: {
                    type: 'linear',
                    position: 'right',
                    beginAtZero: true,
                    max: 100,
                    grid: {
                        drawOnChartArea: false
                    },
                    title: {
                        display: true,
                        text: 'Body Movement %'
                    }
                }
            },
            plugins: {
                annotation: {
                    annotations: {}
                },
                legend: {
                    display: true,
                    position: 'top'
                },
                tooltip: {
                    mode: 'index',
                    intersect: false
                },
                zoom: {
                    zoom: {
                        wheel: {
                            enabled: true,
                            speed: 0.1
                        },
                        pinch: {
                            enabled: true
                        },
                        mode: 'x'
                    },
                    pan: {
                        enabled: true,
                        mode: 'x'
                    },
                    limits: {
                        x: {
                            min: 'original',
                            max: 'original'
                        }
                    }
                }
            }
        }
    });

    // 24-Hour Timeline (works for both modes)
    charts.timeline24Hour = new Chart(document.getElementById('timeline24Hour'), {
        type: 'line',
        data: {
            datasets: [
                {
                    label: 'Existence (0/1)',
                    data: [],
                    borderColor: 'rgb(34, 197, 94)',
                    backgroundColor: 'rgba(34, 197, 94, 0.1)',
                    tension: 0.1,
                    fill: false,
                    pointRadius: 0,
                    borderWidth: 2,
                    spanGaps: false,
                    yAxisID: 'y'
                },
                {
                    label: 'Motion (0-5)',
                    data: [],
                    borderColor: 'rgb(251, 146, 60)',
                    backgroundColor: 'rgba(251, 146, 60, 0.1)',
                    tension: 0.1,
                    fill: false,
                    pointRadius: 0,
                    borderWidth: 2,
                    spanGaps: false,
                    yAxisID: 'y'
                },
                {
                    label: 'Body Movement (0-100)',
                    data: [],
                    borderColor: 'rgb(139, 92, 246)',
                    backgroundColor: 'rgba(139, 92, 246, 0.1)',
                    tension: 0.1,
                    fill: false,
                    pointRadius: 0,
                    borderWidth: 3,
                    spanGaps: false,
                    yAxisID: 'y1'
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
                    type: 'time',
                    time: {
                        unit: 'hour',
                        displayFormats: {
                            hour: 'h:mm a'
                        },
                        tooltipFormat: 'MMM d, h:mm a'
                    },
                    ticks: {
                        maxTicksLimit: 24,
                        autoSkip: true,
                        maxRotation: 45,
                        minRotation: 45
                    },
                    title: {
                        display: true,
                        text: 'Time (Last 24 Hours)'
                    }
                },
                y: {
                    type: 'linear',
                    position: 'left',
                    beginAtZero: true,
                    max: 5,
                    title: {
                        display: true,
                        text: 'Existence / Motion'
                    }
                },
                y1: {
                    type: 'linear',
                    position: 'right',
                    beginAtZero: true,
                    max: 100,
                    grid: {
                        drawOnChartArea: false
                    },
                    title: {
                        display: true,
                        text: 'Body Movement %'
                    }
                }
            },
            plugins: {
                annotation: {
                    annotations: {}
                },
                legend: {
                    display: true,
                    position: 'top'
                },
                tooltip: {
                    mode: 'index',
                    intersect: false
                },
                zoom: {
                    zoom: {
                        wheel: {
                            enabled: true,
                            speed: 0.1
                        },
                        pinch: {
                            enabled: true
                        },
                        mode: 'x'
                    },
                    pan: {
                        enabled: true,
                        mode: 'x'
                    },
                    limits: {
                        x: {
                            min: 'original',
                            max: 'original'
                        }
                    }
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
        const now = new Date();
        const oneHourAgo = new Date(now.getTime() - 60 * 60 * 1000);

        console.log('🔍 Loading 1-hour data from:', oneHourAgo.toLocaleString(), 'to', now.toLocaleString());

        // Query by device_timestamp (when data was actually recorded)
        let query = db
            .from(SUPABASE_CONFIG.table)
            .select('*')
            .gte('device_timestamp', oneHourAgo.toISOString())
            .lte('device_timestamp', now.toISOString())
            .not('device_timestamp', 'is', null)  // Exclude records without device_timestamp
            .order('device_timestamp', { ascending: false })  // Get newest first
            .limit(5000);  // Increased limit for 1-hour window

        if (DASHBOARD_CONFIG.deviceId) {
            query = query.eq('device_id', DASHBOARD_CONFIG.deviceId);
        }

        console.log('📡 Querying by device_timestamp');

        // Don't filter by mode initially - get all data to see what's available
        const { data: allData, error: allError } = await query;

        if (allError) {
            console.error('❌ Query error:', allError);
            throw allError;
        }

        console.log(`📦 Total data points in last hour (all modes): ${allData ? allData.length : 0}`);

        // Reverse the data since we queried in descending order
        const reversedData = allData ? allData.reverse() : [];

        // Now filter by current mode if we have data
        let data = reversedData;
        if (currentMode && reversedData.length > 0) {
            data = reversedData.filter(d => d.sensor_mode === currentMode);
            console.log(`📊 Data points for ${currentMode} mode: ${data.length}`);
        }

        if (data && data.length > 0) {
            hourlyDataBuffer = data;

            const firstTime = new Date(data[0].created_at);
            const lastTime = new Date(data[data.length - 1].created_at);
            const spanMinutes = (lastTime - firstTime) / (1000 * 60);

            console.log(`✅ Loaded ${hourlyDataBuffer.length} data points for 1-hour chart`);
            console.log(`📅 Actual data range: ${firstTime.toLocaleString()} to ${lastTime.toLocaleString()}`);
            console.log(`⏱️ Data spans ${spanMinutes.toFixed(1)} minutes`);

            updateHourlyChart();
        } else {
            console.warn('⚠️ No data found for 1-hour chart');
            console.log('Current mode:', currentMode);
            console.log('Device ID:', DASHBOARD_CONFIG.deviceId);
            console.log('All data available:', allData ? allData.length : 0);
        }
    } catch (error) {
        console.error('❌ Error loading hourly data:', error);
    }
}

// Load 12 hours of historical data for timeline
async function load12HourData() {
    try {
        const now = new Date();
        const twelveHoursAgo = new Date(now.getTime() - 12 * 60 * 60 * 1000);

        console.log('🔍 Loading 12-hour data...');
        console.log('  📅 Local time range:', twelveHoursAgo.toLocaleString(), 'to', now.toLocaleString());
        console.log('  🌐 UTC query range:', twelveHoursAgo.toISOString(), 'to', now.toISOString());
        console.log('🔧 CODE VERSION: v2.1 - Auto-refresh every 2 minutes');

        // Fetch data in batches to bypass Supabase 1000 record limit
        let allData = [];
        let batchSize = 1000;
        let offset = 0;
        let hasMore = true;

        while (hasMore) {
            const query = db
                .from(SUPABASE_CONFIG.table)
                .select('*')
                .gte('device_timestamp', twelveHoursAgo.toISOString())
                .lte('device_timestamp', now.toISOString())
                .not('device_timestamp', 'is', null)
                .eq('device_id', DASHBOARD_CONFIG.deviceId || 'ESP32C6_001')
                .order('device_timestamp', { ascending: false })
                .range(offset, offset + batchSize - 1);

            const { data: batch, error: batchError } = await query;

            if (batchError) {
                console.error('❌ Batch query error:', batchError);
                throw batchError;
            }

            console.log(`📦 Fetched batch ${Math.floor(offset / batchSize) + 1}: ${batch.length} records (offset ${offset})`);

            if (batch && batch.length > 0) {
                allData = allData.concat(batch);
                offset += batch.length;
                hasMore = batch.length === batchSize;  // If we got a full batch, there might be more
            } else {
                hasMore = false;
            }

            // Safety limit: max 10 batches (10,000 records)
            if (offset >= 10000) {
                console.log('⚠️ Reached 10,000 record safety limit');
                hasMore = false;
            }
        }

        console.log(`✅ Total records fetched across all batches: ${allData.length}`);
        console.log(`📦 Total data points in last 12 hours (all modes): ${allData ? allData.length : 0}`);

        // Check what modes and data types are in the data
        if (allData && allData.length > 0) {
            const modes = [...new Set(allData.map(d => d.sensor_mode))];
            const dataTypes = [...new Set(allData.map(d => d.data_type))];
            console.log(`📋 Sensor modes found: ${modes.join(', ')}`);
            console.log(`📋 Data types found: ${dataTypes.join(', ')}`);
            console.log(`🎯 Current dashboard mode: ${currentMode}`);

            // Count by data type
            const keepAliveCount = allData.filter(d => d.data_type === 'keep_alive').length;
            const quickCount = allData.filter(d => d.data_type === 'quick').length;
            console.log(`📊 Keep-alive messages: ${keepAliveCount}, Full data: ${quickCount}`);

            // Show sample timestamps to check for time drift
            if (allData.length > 0) {
                const sample = allData[Math.floor(allData.length / 2)];
                console.log('🔍 Sample data point (middle):');
                console.log('  created_at:', sample.created_at, '→', new Date(sample.created_at).toLocaleString());
                console.log('  device_timestamp:', sample.device_timestamp, '→', sample.device_timestamp ? new Date(sample.device_timestamp).toLocaleString() : 'null');

                // Check for timestamp drift
                if (sample.device_timestamp && sample.created_at) {
                    const drift = new Date(sample.device_timestamp) - new Date(sample.created_at);
                    const driftMinutes = Math.round(drift / 60000);
                    console.log('  ⏰ Time drift: ', driftMinutes, 'minutes (device_timestamp - created_at)');
                }

                console.log('  data_type:', sample.data_type);
                console.log('  human_existence:', sample.human_existence);
                console.log('  body_movement:', sample.body_movement);

                // Check if device_timestamp falls within our query range
                const now = new Date();
                const twelveHoursAgo = new Date(now.getTime() - 12 * 60 * 60 * 1000);
                if (sample.device_timestamp) {
                    const deviceTime = new Date(sample.device_timestamp);
                    const withinRange = deviceTime >= twelveHoursAgo && deviceTime <= now;
                    console.log('  📍 Device timestamp within 12h range?', withinRange);
                    if (!withinRange) {
                        console.warn('  ⚠️ Device timestamp is OUTSIDE the 12-hour window!');
                        console.log('     Query range:', twelveHoursAgo.toLocaleString(), 'to', now.toLocaleString());
                        console.log('     Device time:', deviceTime.toLocaleString());
                    }
                }
            }
        }

        // DON'T filter by mode for timeline - show all activity regardless of mode
        // The timeline should display ALL data from the last 12 hours
        // Reverse the data since we queried in descending order
        let data = allData ? allData.reverse() : [];
        console.log(`📊 Using ${data ? data.length : 0} total data points for timeline (no mode filtering)`);

        if (data && data.length > 0) {
            timeline12HourBuffer = data;

            const firstTime = new Date(data[0].created_at);
            const lastTime = new Date(data[data.length - 1].created_at);
            const spanHours = (lastTime - firstTime) / (1000 * 60 * 60);

            console.log(`✅ Loaded ${timeline12HourBuffer.length} data points for 12-hour timeline`);
            console.log(`📅 Actual data range: ${firstTime.toLocaleString()} to ${lastTime.toLocaleString()}`);
            console.log(`⏱️ Data spans ${spanHours.toFixed(2)} hours`);

            // Log detailed sample data to diagnose flat timeline
            console.log('🔍 SAMPLE DATA ANALYSIS (first 3 points):');
            for (let i = 0; i < Math.min(3, data.length); i++) {
                const d = data[i];
                console.log(`  Point ${i}:`, {
                    time: new Date(d.created_at).toLocaleTimeString(),
                    sensor_mode: d.sensor_mode,
                    // Fall detection fields
                    human_existence: d.human_existence,
                    motion_detected: d.motion_detected,
                    body_movement: d.body_movement,
                    fall_state: d.fall_state,
                    // Sleep mode fields
                    heart_rate_bpm: d.heart_rate_bpm,
                    composite_avg_heartbeat: d.composite_avg_heartbeat,
                    respiration_rate: d.respiration_rate,
                    sleep_state: d.sleep_state,
                    composite_turn_over_count: d.composite_turn_over_count
                });
            }

            update12HourTimeline();
        } else {
            console.warn('⚠️ No data found for 12-hour timeline');
            console.log('Current mode:', currentMode);
            console.log('Device ID:', DASHBOARD_CONFIG.deviceId);
            console.log('All data available:', allData ? allData.length : 0);
        }
    } catch (error) {
        console.error('❌ Error loading 12-hour data:', error);
    }
}

// Load 24-hour historical data for timeline
async function load24HourData() {
    try {
        const now = new Date();
        const twentyFourHoursAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000);

        console.log('🔍 Loading 24-hour data...');
        console.log('  📅 Local time range:', twentyFourHoursAgo.toLocaleString(), 'to', now.toLocaleString());
        console.log('  🌐 UTC query range:', twentyFourHoursAgo.toISOString(), 'to', now.toISOString());
        console.log('🔧 CODE VERSION: v2.1 - Auto-refresh every 2 minutes');

        // Fetch data in batches to bypass Supabase 1000 record limit
        let allData = [];
        let batchSize = 1000;
        let offset = 0;
        let hasMore = true;

        while (hasMore) {
            const query = db
                .from(SUPABASE_CONFIG.table)
                .select('*')
                .gte('device_timestamp', twentyFourHoursAgo.toISOString())
                .lte('device_timestamp', now.toISOString())
                .not('device_timestamp', 'is', null)
                .eq('device_id', DASHBOARD_CONFIG.deviceId || 'ESP32C6_001')
                .order('device_timestamp', { ascending: false })
                .range(offset, offset + batchSize - 1);

            const { data: batch, error: batchError } = await query;

            if (batchError) {
                console.error('❌ Batch query error:', batchError);
                throw batchError;
            }

            console.log(`📦 24h Batch ${Math.floor(offset / batchSize) + 1}: ${batch.length} records (offset ${offset})`);

            if (batch && batch.length > 0) {
                allData = allData.concat(batch);
                offset += batch.length;
                hasMore = batch.length === batchSize;
            } else {
                hasMore = false;
            }

            // Safety limit: max 20 batches (20,000 records)
            if (offset >= 20000) {
                console.log('⚠️ Reached 20,000 record safety limit');
                hasMore = false;
            }
        }

        console.log(`✅ 24h Total records fetched: ${allData.length}`);
        console.log(`📦 Total data points in last 24 hours: ${allData ? allData.length : 0}`);

        if (allData && allData.length > 0) {
            // Reverse the data since we queried in descending order
            const data = allData.reverse();

            // Count data types
            const keepAliveCount = data.filter(d => d.data_type === 'keep_alive').length;
            const quickCount = data.filter(d => d.data_type === 'quick').length;
            console.log(`📊 24h - Keep-alive: ${keepAliveCount}, Full data: ${quickCount}`);

            timeline24HourBuffer = data;

            const firstTime = new Date(allData[0].created_at);
            const lastTime = new Date(allData[allData.length - 1].created_at);
            const spanHours = (lastTime - firstTime) / (1000 * 60 * 60);

            console.log(`✅ Loaded ${timeline24HourBuffer.length} data points for 24-hour timeline`);
            console.log(`📅 Data range: ${firstTime.toLocaleString()} to ${lastTime.toLocaleString()}`);
            console.log(`⏱️ Data spans ${spanHours.toFixed(2)} hours`);

            update24HourTimeline();
        } else {
            console.warn('⚠️ No data found for 24-hour timeline');
        }
    } catch (error) {
        console.error('❌ Error loading 24-hour data:', error);
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

    // Format data as {x: timestamp, y: value} for time-based x-axis
    const existenceData = hourlyDataBuffer.map(d => ({
        x: new Date(d.device_timestamp || d.created_at),
        y: d.human_existence || 0
    }));

    const motionData = hourlyDataBuffer.map(d => ({
        x: new Date(d.device_timestamp || d.created_at),
        y: d.motion_detected || 0
    }));

    const bodyMovementData = hourlyDataBuffer.map(d => ({
        x: new Date(d.device_timestamp || d.created_at),
        y: d.body_movement || 0
    }));

    // Set x-axis to always show last 1 hour
    const now = new Date();
    const oneHourAgo = new Date(now.getTime() - 60 * 60 * 1000);
    charts.motionHour.options.scales.x.min = oneHourAgo;
    charts.motionHour.options.scales.x.max = now;

    charts.motionHour.data.datasets[0].data = existenceData;
    charts.motionHour.data.datasets[1].data = motionData;
    charts.motionHour.data.datasets[2].data = bodyMovementData;
    charts.motionHour.update('none');
}

// Reset timeline zoom to show full 12 hours
function resetTimelineZoom() {
    if (charts.timeline12Hour) {
        charts.timeline12Hour.resetZoom();
        console.log('🔍 Reset zoom to full 12-hour view');
    }
}

// Reset timeline24 zoom to show full 24 hours
function resetTimeline24Zoom() {
    if (charts.timeline24Hour) {
        charts.timeline24Hour.resetZoom();
        console.log('🔍 Reset zoom to full 24-hour view');
    }
}

// Aggregate data into time buckets for performance
function aggregateDataByTime(rawData, bucketSizeMs) {
    if (rawData.length === 0) return [];

    const buckets = new Map();

    // Group data into buckets
    rawData.forEach(point => {
        const timestamp = new Date(point.device_timestamp || point.created_at);
        const bucketKey = Math.floor(timestamp.getTime() / bucketSizeMs) * bucketSizeMs;

        if (!buckets.has(bucketKey)) {
            buckets.set(bucketKey, []);
        }
        buckets.get(bucketKey).push(point);
    });

    // Aggregate each bucket
    const aggregated = [];
    buckets.forEach((points, bucketKey) => {
        // Calculate aggregated values
        const existenceValues = points.map(p => p.human_existence || 0);
        const motionValues = points.map(p => p.motion_detected || 0);
        const movementValues = points.map(p => p.body_movement || 0);

        aggregated.push({
            timestamp: new Date(bucketKey),
            human_existence: Math.max(...existenceValues),  // Max to not miss presence
            motion_detected: Math.max(...motionValues),     // Max to not miss motion
            body_movement: Math.round(movementValues.reduce((a, b) => a + b, 0) / movementValues.length)  // Average for smooth trends
        });
    });

    // Sort by timestamp
    return aggregated.sort((a, b) => a.timestamp - b.timestamp);
}

// Update 12-hour timeline
function update12HourTimeline() {
    if (timeline12HourBuffer.length === 0) {
        console.log('⚠️ Timeline buffer is empty - no data to display');
        return;
    }

    console.log(`📊 Updating 12-hour timeline with ${timeline12HourBuffer.length} raw data points`);

    // Aggregate into 5-minute buckets for performance
    const BUCKET_SIZE = 5 * 60 * 1000; // 5 minutes
    const aggregatedData = aggregateDataByTime(timeline12HourBuffer, BUCKET_SIZE);
    console.log(`📊 Aggregated to ${aggregatedData.length} points (5-min buckets)`);

    // Debug: Show first and last data points
    if (aggregatedData.length > 0) {
        const first = aggregatedData[0];
        const last = aggregatedData[aggregatedData.length - 1];
        console.log('🔍 First aggregated point:', {
            timestamp: first.timestamp,
            human_existence: first.human_existence,
            body_movement: first.body_movement
        });
        console.log('🔍 Last aggregated point:', {
            timestamp: last.timestamp,
            human_existence: last.human_existence,
            body_movement: last.body_movement
        });
    }

    // Format aggregated data as {x: timestamp, y: value} for time-based x-axis
    const existenceData = aggregatedData.map(d => ({
        x: d.timestamp,
        y: d.human_existence
    }));

    const motionData = aggregatedData.map(d => ({
        x: d.timestamp,
        y: d.motion_detected
    }));

    const bodyMovementData = aggregatedData.map(d => ({
        x: d.timestamp,
        y: d.body_movement
    }));

    // Create device status data (1 = online, 2 = offline)
    // Show online (1) when we have data, offline (2) when there are gaps
    const deviceStatusData = [];
    const now = new Date();

    // If we have recent data (within 20 seconds), device is currently online
    if (aggregatedData.length > 0) {
        const lastDataTime = aggregatedData[aggregatedData.length - 1].timestamp;
        const secondsSinceLastData = (now - lastDataTime) / 1000;

        // Add all historical data points as online (1)
        aggregatedData.forEach(d => {
            deviceStatusData.push({ x: d.timestamp, y: 1 });
        });

        // Add current status point
        if (secondsSinceLastData > 20) {
            // Device went offline - add offline point from last data time to now
            deviceStatusData.push({ x: lastDataTime, y: 1 });
            deviceStatusData.push({ x: new Date(lastDataTime.getTime() + 20000), y: 2 });
            deviceStatusData.push({ x: now, y: 2 });
        } else {
            // Device is online - add current online point
            deviceStatusData.push({ x: now, y: 1 });
        }
    } else {
        // No data - show offline for entire period
        const twelveHoursAgo = new Date(now.getTime() - 12 * 60 * 60 * 1000);
        deviceStatusData.push({ x: twelveHoursAgo, y: 2 });
        deviceStatusData.push({ x: now, y: 2 });
    }

    // Set x-axis to always show last 12 hours
    const twelveHoursAgo = new Date(now.getTime() - 12 * 60 * 60 * 1000);
    charts.timeline12Hour.options.scales.x.min = twelveHoursAgo;
    charts.timeline12Hour.options.scales.x.max = now;

    const firstTime = aggregatedData[0] ? aggregatedData[0].timestamp : now;
    const lastTime = aggregatedData[aggregatedData.length - 1] ? aggregatedData[aggregatedData.length - 1].timestamp : now;

    console.log(`🕐 Data range: ${firstTime.toLocaleTimeString()} to ${lastTime.toLocaleTimeString()}`);
    console.log(`📊 Chart X-axis: ${twelveHoursAgo.toLocaleTimeString()} to ${now.toLocaleTimeString()} (fixed 12h scale)`);

    console.log('📊 Setting chart data:', {
        existencePoints: existenceData.length,
        motionPoints: motionData.length,
        bodyMovementPoints: bodyMovementData.length
    });

    // Debug: Check if data has non-zero values
    const nonZeroExistence = existenceData.filter(d => d.y > 0).length;
    const nonZeroMotion = motionData.filter(d => d.y > 0).length;
    const nonZeroMovement = bodyMovementData.filter(d => d.y > 0).length;
    console.log('📊 Non-zero values:', {
        existence: nonZeroExistence,
        motion: nonZeroMotion,
        bodyMovement: nonZeroMovement
    });

    // Debug: Show sample data points
    if (existenceData.length > 0) {
        console.log('🔍 Sample chart data (first point):', {
            x: existenceData[0].x,
            existence: existenceData[0].y,
            motion: motionData[0].y,
            bodyMovement: bodyMovementData[0].y
        });
    }

    charts.timeline12Hour.data.datasets[0].data = existenceData;
    charts.timeline12Hour.data.datasets[1].data = motionData;
    charts.timeline12Hour.data.datasets[2].data = bodyMovementData;
    charts.timeline12Hour.data.datasets[3].data = deviceStatusData;
    charts.timeline12Hour.update('none');

    // Update annotations on timeline after chart data is updated
    updateTimelineAnnotations();
}

// Update 24-hour timeline
function update24HourTimeline() {
    if (timeline24HourBuffer.length === 0) {
        console.log('⚠️ 24-hour timeline buffer is empty - no data to display');
        return;
    }

    console.log(`📊 Updating 24-hour timeline with ${timeline24HourBuffer.length} raw data points`);

    // Aggregate into 10-minute buckets for performance
    const BUCKET_SIZE = 10 * 60 * 1000; // 10 minutes
    const aggregatedData = aggregateDataByTime(timeline24HourBuffer, BUCKET_SIZE);
    console.log(`📊 Aggregated to ${aggregatedData.length} points (10-min buckets)`);

    // Debug: Show first and last data points
    if (aggregatedData.length > 0) {
        const first = aggregatedData[0];
        const last = aggregatedData[aggregatedData.length - 1];
        console.log('🔍 24h First aggregated point:', {
            timestamp: first.timestamp,
            human_existence: first.human_existence,
            body_movement: first.body_movement
        });
        console.log('🔍 24h Last aggregated point:', {
            timestamp: last.timestamp,
            human_existence: last.human_existence,
            body_movement: last.body_movement
        });
    }

    // Format aggregated data as {x: timestamp, y: value} for time-based x-axis
    const existenceData = aggregatedData.map(d => ({
        x: d.timestamp,
        y: d.human_existence
    }));

    const motionData = aggregatedData.map(d => ({
        x: d.timestamp,
        y: d.motion_detected
    }));

    const bodyMovementData = aggregatedData.map(d => ({
        x: d.timestamp,
        y: d.body_movement
    }));

    // Set x-axis to always show last 24 hours
    const now = new Date();
    const twentyFourHoursAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000);
    charts.timeline24Hour.options.scales.x.min = twentyFourHoursAgo;
    charts.timeline24Hour.options.scales.x.max = now;

    const firstTime = aggregatedData[0] ? aggregatedData[0].timestamp : now;
    const lastTime = aggregatedData[aggregatedData.length - 1] ? aggregatedData[aggregatedData.length - 1].timestamp : now;

    console.log(`🕐 Data range: ${firstTime.toLocaleTimeString()} to ${lastTime.toLocaleTimeString()}`);
    console.log(`📊 Chart X-axis: ${twentyFourHoursAgo.toLocaleTimeString()} to ${now.toLocaleTimeString()} (fixed 24h scale)`);

    charts.timeline24Hour.data.datasets[0].data = existenceData;
    charts.timeline24Hour.data.datasets[1].data = motionData;
    charts.timeline24Hour.data.datasets[2].data = bodyMovementData;
    charts.timeline24Hour.update('none');
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

// Reset all metric values to 0 when device is offline
function resetMetricsToZero() {
    // Sleep mode metrics
    document.getElementById('heart-rate').textContent = '0';
    document.getElementById('respiration').textContent = '0';
    document.getElementById('sleep-state').textContent = '--';
    document.getElementById('in-bed').textContent = 'No';
    document.getElementById('sleep-quality').textContent = '0';
    document.getElementById('sleep-time').textContent = '0';
    document.getElementById('apnea').textContent = '0';
    document.getElementById('turnover').textContent = '0';
    document.getElementById('sleep-body-movement').textContent = '0';

    // Fall detection mode metrics
    document.getElementById('fall-state').textContent = '✅ No';
    document.getElementById('existence').textContent = 'No';
    document.getElementById('motion').textContent = 'No';
    document.getElementById('body-movement').textContent = '0';
    document.getElementById('residency-time').textContent = '0';
}

// Clear short-term chart data when device is offline
function clearRealtimeCharts() {
    // Clear hourly motion chart (last 20 readings)
    if (charts.motionHour) {
        charts.motionHour.data.labels = [];
        charts.motionHour.data.datasets.forEach(dataset => {
            dataset.data = [];
        });
        charts.motionHour.update('none');
    }

    // Clear other short-term charts in fall detection mode
    if (currentMode === 'fall_detection') {
        if (charts.motion) {
            charts.motion.data.labels = [];
            charts.motion.data.datasets.forEach(dataset => {
                dataset.data = [];
            });
            charts.motion.update('none');
        }

        if (charts.residency) {
            charts.residency.data.labels = [];
            charts.residency.data.datasets.forEach(dataset => {
                dataset.data = [];
            });
            charts.residency.update('none');
        }
    }

    // Clear hourly data buffer
    hourlyDataBuffer = [];
}

// Check if device is online (received data within last 20 seconds)
function checkDeviceOnlineStatus() {
    const statusElement = document.getElementById('connection-status');
    const dotElement = document.querySelector('.status-dot');
    const sleepMetrics = document.getElementById('sleep-metrics');
    const fallMetrics = document.getElementById('fall-metrics');

    let newState;

    if (!lastDataTimestamp) {
        newState = 'waiting';
        statusElement.textContent = 'Waiting for data...';
        dotElement.style.background = '#f59e0b'; // Orange
        // Show metrics but with zero values
        if (currentMode === 'sleep' && sleepMetrics) {
            sleepMetrics.style.display = 'grid';
        } else if (currentMode === 'fall_detection' && fallMetrics) {
            fallMetrics.style.display = 'grid';
        }
        // Only reset if state changed
        if (deviceOnlineState !== newState) {
            resetMetricsToZero();
            clearRealtimeCharts();
        }
        deviceOnlineState = newState;
        return;
    }

    const now = new Date();
    const lastData = new Date(lastDataTimestamp);
    const secondsSinceLastData = (now - lastData) / 1000;

    // Device is online if data received within last 20 seconds (faster detection)
    const ONLINE_THRESHOLD = 20; // seconds

    if (secondsSinceLastData <= ONLINE_THRESHOLD) {
        newState = 'online';
        statusElement.textContent = 'Online';
        dotElement.style.background = '#10b981'; // Green
        // Show metrics when online
        if (currentMode === 'sleep' && sleepMetrics) {
            sleepMetrics.style.display = 'grid';
        } else if (currentMode === 'fall_detection' && fallMetrics) {
            fallMetrics.style.display = 'grid';
        }
    } else if (secondsSinceLastData <= 60) {
        newState = 'stale';
        statusElement.textContent = `Stale (${Math.round(secondsSinceLastData)}s ago)`;
        dotElement.style.background = '#f59e0b'; // Orange
        // Keep metrics visible but reset to zero
        if (currentMode === 'sleep' && sleepMetrics) {
            sleepMetrics.style.display = 'grid';
        } else if (currentMode === 'fall_detection' && fallMetrics) {
            fallMetrics.style.display = 'grid';
        }
        // Only reset/clear if state changed to stale
        if (deviceOnlineState !== 'stale' && deviceOnlineState !== 'offline') {
            resetMetricsToZero();
            clearRealtimeCharts();
        }
    } else {
        newState = 'offline';
        statusElement.textContent = 'Offline';
        dotElement.style.background = '#ef4444'; // Red
        // Keep metrics visible but reset to zero
        if (currentMode === 'sleep' && sleepMetrics) {
            sleepMetrics.style.display = 'grid';
        } else if (currentMode === 'fall_detection' && fallMetrics) {
            fallMetrics.style.display = 'grid';
        }
        // Only reset/clear if state changed to offline
        if (deviceOnlineState !== 'offline' && deviceOnlineState !== 'stale') {
            resetMetricsToZero();
            clearRealtimeCharts();
        }
    }

    deviceOnlineState = newState;
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

    // Sensor query settings sliders
    setupSlider('query-delay', 'query-delay-value');
    setupSlider('retry-attempts', 'retry-attempts-value');
    setupSlider('retry-delay', 'retry-delay-value');

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

// Setup data collection mode slider (converts number to text)
function setupDataCollectionModeSlider() {
    const slider = document.getElementById('data-collection-mode-slider');
    const valueDisplay = document.getElementById('data-collection-mode-value');

    if (slider && valueDisplay) {
        slider.addEventListener('input', (e) => {
            const modes = { '1': 'Quick', '2': 'Medium' };
            valueDisplay.textContent = modes[e.target.value] || 'Quick';
        });
    }
}

// Call this on page load
setupDataCollectionModeSlider();

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

            // Sensor query settings
            updateSlider('query-delay', data.sensor_query_delay_ms || 0);
            updateSlider('retry-attempts', data.query_retry_attempts || 1);
            updateSlider('retry-delay', data.query_retry_delay_ms || 100);
            document.getElementById('supplemental-queries-toggle').checked = data.enable_supplemental_queries !== false;

            // Set data collection mode slider and display
            const modeValue = data.data_collection_mode === 'medium' ? 2 : 1;
            const modeSlider = document.getElementById('data-collection-mode-slider');
            const modeDisplay = document.getElementById('data-collection-mode-value');
            if (modeSlider) {
                modeSlider.value = modeValue;
                if (modeDisplay) {
                    modeDisplay.textContent = modeValue === 1 ? 'Quick' : 'Medium';
                }
            }

            const supplementalModeSelect = document.getElementById('supplemental-mode-select');
            if (supplementalModeSelect) {
                supplementalModeSelect.value = data.supplemental_cycle_mode || 'rotating';
            }

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

// ========================================
// Timeline Annotation Functions
// ========================================

// Load user annotations from database
async function loadUserAnnotations() {
    try {
        const twelveHoursAgo = new Date(Date.now() - 12 * 60 * 60 * 1000).toISOString();

        const { data, error } = await db
            .from('timeline_annotations')
            .select('*')
            .eq('device_id', DASHBOARD_CONFIG.deviceId || 'ESP32C6_001')
            .gte('annotation_timestamp', twelveHoursAgo)
            .order('annotation_timestamp', { ascending: false });

        if (error) throw error;

        userAnnotations = data || [];
        console.log(`Loaded ${userAnnotations.length} user annotations`);

        // Update timeline chart with annotations
        if (charts.timeline12Hour) {
            updateTimelineAnnotations();
        }

        // Update annotations list in modal
        updateAnnotationsList();
    } catch (error) {
        console.error('Error loading annotations:', error);
    }
}

// Update timeline chart with all annotations
function updateTimelineAnnotations() {
    if (!charts.timeline12Hour) return;

    const annotations = {};

    // Add mode change annotations
    let previousMode = null;
    timeline12HourBuffer.forEach((point, index) => {
        // Show initial mode at the start
        if (index === 0 && point.sensor_mode) {
            const timestamp = new Date(point.device_timestamp || point.created_at);
            const timeLabel = timestamp.toLocaleTimeString('en-US', {
                hour: '2-digit',
                minute: '2-digit',
                hour12: true
            });

            const modeLabel = point.sensor_mode === 'sleep' ? '😴 Sleep Mode' : '🚨 Fall Detection';
            const modeColor = point.sensor_mode === 'sleep' ? '#8b5cf6' : '#f59e0b';

            annotations[`mode_initial`] = {
                type: 'line',
                xMin: timestamp.getTime(),  // Use timestamp in milliseconds for time axis
                xMax: timestamp.getTime(),
                borderColor: modeColor,
                borderWidth: 3,
                borderDash: [10, 5],
                label: {
                    display: true,
                    content: `${modeLabel} Started`,
                    position: 'end',
                    yAdjust: -10,
                    backgroundColor: modeColor,
                    color: 'white',
                    font: {
                        size: 12,
                        weight: 'bold'
                    },
                    padding: 8,
                    borderRadius: 6
                }
            };

            console.log(`📍 Initial mode: ${point.sensor_mode} at ${timeLabel}`);
        }

        if (previousMode !== null && point.sensor_mode !== previousMode) {
            // Mode changed - add annotation
            const timestamp = new Date(point.device_timestamp || point.created_at);
            const timeLabel = timestamp.toLocaleTimeString('en-US', {
                hour: '2-digit',
                minute: '2-digit',
                hour12: true
            });

            const modeLabel = point.sensor_mode === 'sleep' ? '😴 Sleep Mode' : '🚨 Fall Detection';
            const modeColor = point.sensor_mode === 'sleep' ? '#8b5cf6' : '#f59e0b';

            annotations[`mode_change_${index}`] = {
                type: 'line',
                xMin: timestamp.getTime(),  // Use timestamp in milliseconds for time axis
                xMax: timestamp.getTime(),
                borderColor: modeColor,
                borderWidth: 3,
                borderDash: [10, 5],
                label: {
                    display: true,
                    content: `${modeLabel}`,
                    position: 'end',
                    yAdjust: -10,
                    backgroundColor: modeColor,
                    color: 'white',
                    font: {
                        size: 12,
                        weight: 'bold'
                    },
                    padding: 8,
                    borderRadius: 6
                }
            };

            console.log(`🔄 Mode change detected at ${timeLabel}: ${previousMode} → ${point.sensor_mode}`);
        }
        previousMode = point.sensor_mode;
    });

    // Add user annotations
    console.log(`📝 Adding ${userAnnotations.length} user annotations to timeline`);
    userAnnotations.forEach((annotation, index) => {
        const timestamp = new Date(annotation.annotation_timestamp);
        const timeLabel = timestamp.toLocaleTimeString('en-US', {
            hour: '2-digit',
            minute: '2-digit',
            hour12: true
        });

        console.log(`  📌 Annotation: "${annotation.title}" at ${timeLabel} (${timestamp.toISOString()})`);

        annotations[`user_${annotation.id}`] = {
            type: 'line',
            xMin: timestamp.getTime(),  // Use timestamp in milliseconds for time axis
            xMax: timestamp.getTime(),
            borderColor: annotation.color || '#667eea',
            borderWidth: 2,
            borderDash: [4, 4],
            label: {
                display: true,
                content: `${annotation.icon || '📝'} ${annotation.title}`,
                position: 'end',
                yAdjust: -10,
                backgroundColor: annotation.color || '#667eea',
                color: 'white',
                font: {
                    size: 11,
                    weight: 'bold'
                },
                padding: 6,
                borderRadius: 4
            }
        };
    });

    // Add auto-detected event annotations
    timeline12HourBuffer.forEach((point, index) => {
        const timestamp = new Date(point.device_timestamp || point.created_at);
        const timeLabel = timestamp.toLocaleTimeString('en-US', {
            hour: '2-digit',
            minute: '2-digit',
            hour12: true
        });

        // Fall detection
        if (point.fall_state > 0) {
            annotations[`fall_${index}`] = {
                type: 'line',
                xMin: timeLabel,
                xMax: timeLabel,
                borderColor: 'rgb(239, 68, 68)',
                borderWidth: 3,
                borderDash: [6, 6],
                label: {
                    display: true,
                    content: '🚨 Fall Detected',
                    position: 'start',
                    backgroundColor: 'rgba(239, 68, 68, 0.9)',
                    color: 'white',
                    font: { size: 11, weight: 'bold' }
                }
            };
        }

        // Apnea events
        if (point.composite_apnea_events > 0) {
            const activityIndex = timeline12HourBuffer.indexOf(point);
            const activityData = charts.timeline12Hour.data.datasets[0].data;

            annotations[`apnea_${index}`] = {
                type: 'point',
                xValue: timeLabel,
                yValue: activityData[activityIndex] || 0,
                backgroundColor: 'rgb(220, 38, 38)',
                borderColor: 'rgb(185, 28, 28)',
                borderWidth: 2,
                radius: 7,
                label: {
                    display: true,
                    content: `⚠️ Apnea (${point.composite_apnea_events})`,
                    position: 'top',
                    backgroundColor: 'rgba(220, 38, 38, 0.9)',
                    color: 'white',
                    font: { size: 10 }
                }
            };
        }

        // Door events
        if (point.door_event > 0) {
            annotations[`door_${index}`] = {
                type: 'line',
                xMin: timeLabel,
                xMax: timeLabel,
                borderColor: 'rgb(139, 92, 246)',
                borderWidth: 2,
                borderDash: [4, 4],
                label: {
                    display: true,
                    content: `🚪 Door (${point.door_event})`,
                    position: 'end',
                    backgroundColor: 'rgba(139, 92, 246, 0.9)',
                    color: 'white',
                    font: { size: 10, weight: 'bold' }
                }
            };
        }
    });

    // Update chart
    if (!charts.timeline12Hour.options.plugins.annotation) {
        charts.timeline12Hour.options.plugins.annotation = { annotations: {} };
    }
    const annotationCount = Object.keys(annotations).length;
    console.log(`🎨 Updating chart with ${annotationCount} total annotations`);
    console.log('📋 Annotation objects:', annotations);
    charts.timeline12Hour.options.plugins.annotation.annotations = annotations;

    // Force a full chart update
    charts.timeline12Hour.update();

    console.log(`✅ Chart annotations updated`);
    console.log('🔍 Current chart annotations:', charts.timeline12Hour.options.plugins.annotation.annotations);
}

// Open annotation modal
function openAnnotationModal(annotationId = null) {
    const modal = document.getElementById('annotationModal');
    const form = document.getElementById('annotationForm');
    const deleteBtn = document.getElementById('delete-annotation-btn');

    // Reset form
    form.reset();
    document.getElementById('annotation-id').value = '';
    document.getElementById('annotation-color').value = '#667eea';
    document.getElementById('annotation-icon').value = '📝';
    deleteBtn.style.display = 'none';

    // Set default date/time to now (in local timezone)
    const now = new Date();
    const year = now.getFullYear();
    const month = String(now.getMonth() + 1).padStart(2, '0');
    const day = String(now.getDate()).padStart(2, '0');
    const hours = String(now.getHours()).padStart(2, '0');
    const minutes = String(now.getMinutes()).padStart(2, '0');

    document.getElementById('annotation-date').value = `${year}-${month}-${day}`;
    document.getElementById('annotation-time').value = `${hours}:${minutes}`;

    // If editing existing annotation
    if (annotationId) {
        const annotation = userAnnotations.find(a => a.id === annotationId);
        if (annotation) {
            const timestamp = new Date(annotation.annotation_timestamp);
            document.getElementById('annotation-id').value = annotation.id;
            document.getElementById('annotation-title').value = annotation.title;
            document.getElementById('annotation-description').value = annotation.description || '';

            // Format date and time in local timezone
            const year = timestamp.getFullYear();
            const month = String(timestamp.getMonth() + 1).padStart(2, '0');
            const day = String(timestamp.getDate()).padStart(2, '0');
            const hours = String(timestamp.getHours()).padStart(2, '0');
            const minutes = String(timestamp.getMinutes()).padStart(2, '0');

            document.getElementById('annotation-date').value = `${year}-${month}-${day}`;
            document.getElementById('annotation-time').value = `${hours}:${minutes}`;
            document.getElementById('annotation-type').value = annotation.annotation_type;
            document.getElementById('annotation-color').value = annotation.color;
            document.getElementById('annotation-icon').value = annotation.icon;
            deleteBtn.style.display = 'block';
        }
    }

    modal.classList.add('active');
}

// Close annotation modal
function closeAnnotationModal() {
    const modal = document.getElementById('annotationModal');
    modal.classList.remove('active');
}

// Toggle emoji picker
function toggleEmojiPicker() {
    const picker = document.getElementById('emoji-picker');
    picker.style.display = picker.style.display === 'none' ? 'grid' : 'none';
}

// Select emoji
function selectEmoji(emoji) {
    document.getElementById('annotation-icon').value = emoji;
    document.getElementById('emoji-picker').style.display = 'none';
}

// Save annotation
async function saveAnnotation(event) {
    event.preventDefault();

    const annotationId = document.getElementById('annotation-id').value;
    const title = document.getElementById('annotation-title').value;
    const description = document.getElementById('annotation-description').value;
    const date = document.getElementById('annotation-date').value;
    const time = document.getElementById('annotation-time').value;
    const type = document.getElementById('annotation-type').value;
    const color = document.getElementById('annotation-color').value;
    const icon = document.getElementById('annotation-icon').value;

    console.log(`📝 Form values: date="${date}", time="${time}"`);

    // Combine date and time, treating as local time
    // Split the time to get hours and minutes
    const [hours, minutes] = time.split(':').map(Number);
    const [year, month, day] = date.split('-').map(Number);

    console.log(`📝 Parsed: year=${year}, month=${month}, day=${day}, hours=${hours}, minutes=${minutes}`);

    // Create date in local timezone, then convert to ISO
    const localDate = new Date(year, month - 1, day, hours, minutes, 0);
    const timestamp = localDate.toISOString();

    console.log(`📅 Creating annotation: ${date} ${time} (local) → ${localDate.toString()} → ${timestamp} (UTC)`);

    const annotationData = {
        device_id: DASHBOARD_CONFIG.deviceId || 'ESP32C6_001',
        annotation_timestamp: timestamp,
        annotation_type: type,
        title: title,
        description: description,
        color: color,
        icon: icon
    };

    try {
        if (annotationId) {
            // Update existing annotation
            const { error } = await db
                .from('timeline_annotations')
                .update(annotationData)
                .eq('id', annotationId);

            if (error) throw error;
            console.log('Annotation updated successfully');
        } else {
            // Create new annotation
            const { error } = await db
                .from('timeline_annotations')
                .insert([annotationData]);

            if (error) throw error;
            console.log('Annotation created successfully');
        }

        // Reload annotations and close modal
        await loadUserAnnotations();
        closeAnnotationModal();

    } catch (error) {
        console.error('Error saving annotation:', error);
        console.error('Error details:', {
            message: error.message,
            code: error.code,
            details: error.details,
            hint: error.hint
        });
        alert(`❌ Failed to save annotation.\n\nError: ${error.message || error}\n\nCheck console for details.`);
    }
}

// Delete annotation
async function deleteAnnotation() {
    const annotationId = document.getElementById('annotation-id').value;
    if (!annotationId) return;

    if (!confirm('Are you sure you want to delete this annotation?')) {
        return;
    }

    try {
        const { error } = await db
            .from('timeline_annotations')
            .delete()
            .eq('id', annotationId);

        if (error) throw error;

        console.log('Annotation deleted successfully');
        await loadUserAnnotations();
        closeAnnotationModal();

    } catch (error) {
        console.error('Error deleting annotation:', error);
        alert('❌ Failed to delete annotation. Please try again.');
    }
}

// Update annotations list in modal
function updateAnnotationsList() {
    const listContainer = document.getElementById('annotations-list');

    if (userAnnotations.length === 0) {
        listContainer.innerHTML = '<p style="text-align: center; color: #999; padding: 20px;">No annotations yet</p>';
        return;
    }

    listContainer.innerHTML = userAnnotations.map(annotation => {
        const timestamp = new Date(annotation.annotation_timestamp);
        const formattedTime = timestamp.toLocaleString('en-US', {
            month: 'short',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit',
            hour12: true
        });

        return `
            <div class="annotation-item">
                <div class="annotation-info">
                    <div class="annotation-title">
                        ${annotation.icon || '📝'} ${annotation.title}
                    </div>
                    <div class="annotation-time">${formattedTime}</div>
                </div>
                <div class="annotation-actions">
                    <button class="icon-btn" onclick="openAnnotationModal('${annotation.id}')" title="Edit">✏️</button>
                </div>
            </div>
        `;
    }).join('');
}

// Close modal when clicking outside
window.onclick = function(event) {
    const modal = document.getElementById('annotationModal');
    if (event.target === modal) {
        closeAnnotationModal();
    }
}

// Refresh all timelines with fresh historical data from database
async function refreshTimelineData() {
    console.log('🔄 Manual refresh triggered - reloading ALL historical data from database...');

    try {
        // Clear existing buffers
        const previous12HourCount = timeline12HourBuffer.length;
        const previousHourlyCount = hourlyDataBuffer.length;
        timeline12HourBuffer = [];
        hourlyDataBuffer = [];

        console.log(`🗑️ Cleared ${previous12HourCount} 12-hour data points and ${previousHourlyCount} hourly data points`);

        // Reload from database
        await load12HourData();
        await loadHourlyData();

        console.log('✅ Historical data refresh complete');
        alert(`✅ Refreshed timelines:\n• 12-hour: ${timeline12HourBuffer.length} data points\n• 1-hour: ${hourlyDataBuffer.length} data points`);
    } catch (error) {
        console.error('❌ Error refreshing timeline data:', error);
        alert('❌ Failed to refresh timeline data. Check console for details.');
    }
}

// Refresh 24-hour timeline data
async function refreshTimeline24Data() {
    console.log('🔄 Manual refresh triggered - reloading 24-hour historical data from database...');

    try {
        const previous24HourCount = timeline24HourBuffer.length;
        timeline24HourBuffer = [];

        console.log(`🗑️ Cleared ${previous24HourCount} 24-hour data points`);

        await load24HourData();

        console.log('✅ 24-hour data refresh complete');
        alert(`✅ Refreshed 24-hour timeline: ${timeline24HourBuffer.length} data points`);
    } catch (error) {
        console.error('❌ Error refreshing 24-hour timeline data:', error);
        alert('❌ Failed to refresh 24-hour timeline data. Check console for details.');
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
        'query-delay': 0,
        'retry-attempts': 1,
        'retry-delay': 100,
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

    // Reset toggles
    document.getElementById('position-tracking-toggle').checked = true;
    document.getElementById('supplemental-queries-toggle').checked = true;

    // Reset supplemental mode select
    const supplementalModeSelect = document.getElementById('supplemental-mode-select');
    if (supplementalModeSelect) {
        supplementalModeSelect.value = 'rotating';
    }

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

            // Sensor query settings
            data_collection_mode: parseInt(document.getElementById('data-collection-mode-slider').value) === 1 ? 'quick' : 'medium',
            sensor_query_delay_ms: parseInt(document.getElementById('query-delay-slider').value),
            query_retry_attempts: parseInt(document.getElementById('retry-attempts-slider').value),
            query_retry_delay_ms: parseInt(document.getElementById('retry-delay-slider').value),
            enable_supplemental_queries: document.getElementById('supplemental-queries-toggle').checked,
            supplemental_cycle_mode: document.getElementById('supplemental-mode-select').value,

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
