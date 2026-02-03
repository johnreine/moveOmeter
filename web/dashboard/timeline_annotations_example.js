/**
 * Timeline Annotations Examples for moveOmeter Dashboard
 *
 * This file demonstrates various annotation types you can add to the 12-hour timeline
 * using Chart.js annotation plugin.
 *
 * Copy the relevant sections into dashboard.js and adapt as needed.
 */

// Example 1: Enhanced 12-Hour Timeline with Annotations
function create12HourTimelineWithAnnotations() {
    const ctx = document.getElementById('timeline12Hour').getContext('2d');

    return new Chart(ctx, {
        type: 'line',
        data: {
            labels: [], // Your time labels
            datasets: [{
                label: 'Activity Level',
                data: [], // Your data
                borderColor: 'rgb(102, 126, 234)',
                backgroundColor: 'rgba(102, 126, 234, 0.2)',
                tension: 0.3,
                fill: true,
                pointRadius: 0,
                borderWidth: 2
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: true,
            plugins: {
                annotation: {
                    annotations: {
                        // Example: Fall event marker (red vertical line)
                        fall1: {
                            type: 'line',
                            xMin: '14:23:45',  // Time of fall
                            xMax: '14:23:45',
                            borderColor: 'rgb(255, 99, 132)',
                            borderWidth: 3,
                            borderDash: [6, 6],
                            label: {
                                display: true,
                                content: '🚨 Fall Detected',
                                position: 'start',
                                backgroundColor: 'rgba(255, 99, 132, 0.9)',
                                color: 'white',
                                font: {
                                    size: 11,
                                    weight: 'bold'
                                }
                            }
                        },

                        // Example: Sleep period (shaded box)
                        sleepPeriod: {
                            type: 'box',
                            xMin: '22:00:00',
                            xMax: '06:30:00',
                            backgroundColor: 'rgba(99, 102, 241, 0.1)',
                            borderColor: 'rgba(99, 102, 241, 0.5)',
                            borderWidth: 1,
                            label: {
                                display: true,
                                content: '😴 Sleep Period',
                                position: 'center',
                                font: {
                                    size: 10
                                },
                                color: 'rgb(99, 102, 241)'
                            }
                        },

                        // Example: Threshold line (e.g., low activity warning)
                        lowActivityThreshold: {
                            type: 'line',
                            yMin: 20,
                            yMax: 20,
                            borderColor: 'rgb(251, 146, 60)',
                            borderWidth: 2,
                            borderDash: [5, 5],
                            label: {
                                display: true,
                                content: 'Low Activity Threshold',
                                position: 'end',
                                backgroundColor: 'rgba(251, 146, 60, 0.8)',
                                color: 'white',
                                font: {
                                    size: 10
                                }
                            }
                        },

                        // Example: Out of bed event (point annotation)
                        outOfBed: {
                            type: 'point',
                            xValue: '03:15:30',
                            yValue: 45,
                            backgroundColor: 'rgb(234, 179, 8)',
                            borderColor: 'rgb(202, 138, 4)',
                            borderWidth: 2,
                            radius: 8,
                            label: {
                                display: true,
                                content: '🛏️ Left Bed',
                                position: 'top',
                                backgroundColor: 'rgba(234, 179, 8, 0.9)',
                                color: 'white',
                                font: {
                                    size: 10,
                                    weight: 'bold'
                                }
                            }
                        },

                        // Example: Medication time reminder
                        medicationTime: {
                            type: 'line',
                            xMin: '08:00:00',
                            xMax: '08:00:00',
                            borderColor: 'rgb(34, 197, 94)',
                            borderWidth: 2,
                            label: {
                                display: true,
                                content: '💊 Medication',
                                position: 'start',
                                backgroundColor: 'rgba(34, 197, 94, 0.9)',
                                color: 'white',
                                font: {
                                    size: 10
                                }
                            }
                        }
                    }
                },
                legend: {
                    display: true,
                    position: 'top'
                },
                tooltip: {
                    mode: 'index',
                    intersect: false,
                    callbacks: {
                        // Custom tooltip to show annotations
                        afterBody: function(context) {
                            const annotations = [];
                            // Add annotation info to tooltip if near annotation
                            return annotations;
                        }
                    }
                }
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
            }
        }
    });
}

// Example 2: Dynamically Add Annotations from Database Events
function addEventAnnotations(chart, events) {
    const annotations = {};

    events.forEach((event, index) => {
        const annotationId = `event_${index}`;

        switch(event.type) {
            case 'fall':
                annotations[annotationId] = {
                    type: 'line',
                    xMin: event.timestamp,
                    xMax: event.timestamp,
                    borderColor: 'rgb(239, 68, 68)',
                    borderWidth: 3,
                    borderDash: [6, 6],
                    label: {
                        display: true,
                        content: `🚨 Fall (${event.duration}s)`,
                        position: 'start',
                        backgroundColor: 'rgba(239, 68, 68, 0.9)',
                        color: 'white',
                        font: { size: 11, weight: 'bold' }
                    }
                };
                break;

            case 'sleep_start':
                annotations[annotationId] = {
                    type: 'point',
                    xValue: event.timestamp,
                    yValue: event.activityLevel || 0,
                    backgroundColor: 'rgb(99, 102, 241)',
                    borderColor: 'rgb(79, 70, 229)',
                    borderWidth: 2,
                    radius: 6,
                    label: {
                        display: true,
                        content: '😴 Sleep',
                        position: 'top',
                        backgroundColor: 'rgba(99, 102, 241, 0.9)',
                        color: 'white'
                    }
                };
                break;

            case 'wake_up':
                annotations[annotationId] = {
                    type: 'point',
                    xValue: event.timestamp,
                    yValue: event.activityLevel || 0,
                    backgroundColor: 'rgb(234, 179, 8)',
                    borderColor: 'rgb(202, 138, 4)',
                    borderWidth: 2,
                    radius: 6,
                    label: {
                        display: true,
                        content: '⏰ Wake Up',
                        position: 'top',
                        backgroundColor: 'rgba(234, 179, 8, 0.9)',
                        color: 'white'
                    }
                };
                break;

            case 'high_activity':
                annotations[annotationId] = {
                    type: 'box',
                    xMin: event.startTime,
                    xMax: event.endTime,
                    backgroundColor: 'rgba(34, 197, 94, 0.1)',
                    borderColor: 'rgba(34, 197, 94, 0.5)',
                    borderWidth: 1,
                    label: {
                        display: true,
                        content: '🏃 Active Period',
                        position: 'start',
                        color: 'rgb(34, 197, 94)'
                    }
                };
                break;

            case 'apnea':
                annotations[annotationId] = {
                    type: 'point',
                    xValue: event.timestamp,
                    yValue: event.activityLevel || 0,
                    backgroundColor: 'rgb(220, 38, 38)',
                    borderColor: 'rgb(185, 28, 28)',
                    borderWidth: 2,
                    radius: 7,
                    label: {
                        display: true,
                        content: '⚠️ Apnea Event',
                        position: 'top',
                        backgroundColor: 'rgba(220, 38, 38, 0.9)',
                        color: 'white'
                    }
                };
                break;
        }
    });

    // Update chart annotations
    chart.options.plugins.annotation.annotations = annotations;
    chart.update('none');
}

// Example 3: Load Events from Database and Annotate Timeline
async function loadAndAnnotateTimeline(chart) {
    try {
        // Fetch events from last 12 hours
        const twelveHoursAgo = new Date(Date.now() - 12 * 60 * 60 * 1000).toISOString();

        const { data: events, error } = await db
            .from('sensor_events')  // You'd need to create this table
            .select('*')
            .gte('created_at', twelveHoursAgo)
            .eq('device_id', 'ESP32C6_001')
            .order('created_at', { ascending: true });

        if (error) throw error;

        if (events && events.length > 0) {
            addEventAnnotations(chart, events);
            console.log(`Added ${events.length} event annotations to timeline`);
        }
    } catch (error) {
        console.error('Error loading timeline events:', error);
    }
}

// Example 4: Real-Time Annotation Updates
function handleNewEvent(chart, eventData) {
    const timestamp = new Date(eventData.device_timestamp || eventData.created_at)
        .toLocaleTimeString('en-US', {
            hour: '2-digit',
            minute: '2-digit',
            second: '2-digit',
            hour12: true
        });

    // Create new annotation
    const annotationId = `event_${Date.now()}`;
    const newAnnotation = createAnnotationForEvent(eventData, timestamp);

    // Add to chart
    if (!chart.options.plugins.annotation) {
        chart.options.plugins.annotation = { annotations: {} };
    }

    chart.options.plugins.annotation.annotations[annotationId] = newAnnotation;
    chart.update('none');

    // Auto-remove old annotations (optional)
    cleanupOldAnnotations(chart);
}

// Helper: Create annotation based on event type
function createAnnotationForEvent(event, timestamp) {
    // Detect event type from data
    if (event.fall_state > 0) {
        return {
            type: 'line',
            xMin: timestamp,
            xMax: timestamp,
            borderColor: 'rgb(239, 68, 68)',
            borderWidth: 3,
            borderDash: [6, 6],
            label: {
                display: true,
                content: '🚨 Fall',
                position: 'start',
                backgroundColor: 'rgba(239, 68, 68, 0.9)',
                color: 'white',
                font: { size: 11, weight: 'bold' }
            }
        };
    } else if (event.composite_apnea_events > 0) {
        return {
            type: 'point',
            xValue: timestamp,
            yValue: event.body_movement || 0,
            backgroundColor: 'rgb(220, 38, 38)',
            borderColor: 'rgb(185, 28, 28)',
            borderWidth: 2,
            radius: 7,
            label: {
                display: true,
                content: `⚠️ Apnea (${event.composite_apnea_events})`,
                position: 'top',
                backgroundColor: 'rgba(220, 38, 38, 0.9)',
                color: 'white',
                font: { size: 10 }
            }
        };
    }

    return null;
}

// Helper: Remove annotations older than 12 hours
function cleanupOldAnnotations(chart) {
    const now = Date.now();
    const twelveHours = 12 * 60 * 60 * 1000;
    const annotations = chart.options.plugins.annotation.annotations;

    Object.keys(annotations).forEach(key => {
        // Parse timestamp from annotation and remove if too old
        // This is simplified - you'd need proper timestamp parsing
    });
}

// Example 5: Interactive Annotations (Click to See Details)
function addClickableAnnotations(chart) {
    chart.options.onClick = (event, activeElements, chart) => {
        const annotations = chart.options.plugins.annotation.annotations;

        // Check if click was near an annotation
        Object.keys(annotations).forEach(key => {
            const annotation = annotations[key];
            // Show details modal or tooltip
            // You'd implement hit detection here
        });
    };
}

// Example 6: Sleep Period Detection and Annotation
function annotateSleepPeriods(chart, data) {
    let sleepStart = null;
    const sleepThreshold = 20; // Activity level threshold

    data.forEach((point, index) => {
        const timestamp = point.timestamp;
        const activity = point.activityLevel;

        // Detect sleep start
        if (activity < sleepThreshold && sleepStart === null) {
            sleepStart = timestamp;
        }

        // Detect sleep end
        if (activity >= sleepThreshold && sleepStart !== null) {
            // Create sleep period annotation
            const annotationId = `sleep_${sleepStart}`;
            chart.options.plugins.annotation.annotations[annotationId] = {
                type: 'box',
                xMin: sleepStart,
                xMax: timestamp,
                backgroundColor: 'rgba(99, 102, 241, 0.15)',
                borderColor: 'rgba(99, 102, 241, 0.5)',
                borderWidth: 1,
                label: {
                    display: true,
                    content: '😴 Sleep',
                    position: 'center',
                    color: 'rgb(99, 102, 241)',
                    font: { size: 10 }
                }
            };

            sleepStart = null;
        }
    });

    chart.update('none');
}

/**
 * Usage in dashboard.js:
 *
 * 1. Initialize timeline with annotation support:
 *    charts.timeline12Hour = create12HourTimelineWithAnnotations();
 *
 * 2. Load existing events:
 *    loadAndAnnotateTimeline(charts.timeline12Hour);
 *
 * 3. Handle real-time events:
 *    function addNewDataPoint(newData) {
 *        // ... existing code ...
 *        handleNewEvent(charts.timeline12Hour, newData);
 *    }
 *
 * 4. Detect and annotate sleep periods:
 *    annotateSleepPeriods(charts.timeline12Hour, timeline12HourBuffer);
 */
