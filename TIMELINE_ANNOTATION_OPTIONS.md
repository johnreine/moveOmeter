# Timeline Annotation Options for moveOmeter Dashboard

Comprehensive comparison of graphing libraries for timeline visualizations with annotations.

## Quick Recommendation

**For your use case (12-hour activity timeline with event markers):**

1. **Best Overall**: Chart.js + Annotation Plugin ⭐ (Already using it!)
2. **Most Timeline-Specific**: vis.js Timeline
3. **Most Powerful**: ApexCharts or Plotly.js
4. **Ultimate Flexibility**: D3.js (if you have time)

## Detailed Comparison

### 1. Chart.js + chartjs-plugin-annotation ⭐

**Pros:**
- ✅ You're already using Chart.js
- ✅ Lightweight and fast
- ✅ Excellent annotation plugin
- ✅ Easy to implement
- ✅ Good documentation
- ✅ Supports: vertical/horizontal lines, boxes, points, labels, polygons
- ✅ Real-time updates work smoothly

**Cons:**
- ❌ Less specialized for pure timeline views
- ❌ Limited interactive timeline features

**Best For:**
- Quick implementation (1-2 hours)
- Standard time-series with annotations
- Lightweight dashboards

**Code Example:**
```javascript
plugins: {
    annotation: {
        annotations: {
            fallEvent: {
                type: 'line',
                xMin: '14:23:45',
                xMax: '14:23:45',
                borderColor: 'rgb(255, 99, 132)',
                borderWidth: 3,
                label: {
                    display: true,
                    content: '🚨 Fall Detected'
                }
            }
        }
    }
}
```

**Installation:**
```html
<script src="https://cdn.jsdelivr.net/npm/chartjs-plugin-annotation@3.0.1"></script>
```

---

### 2. ApexCharts

**Pros:**
- ✅ Modern, beautiful out-of-the-box
- ✅ Excellent annotation support (native, not plugin)
- ✅ Built-in zooming, panning
- ✅ Interactive tooltips
- ✅ Responsive design
- ✅ Good for medical/healthcare data
- ✅ Supports: points, lines, ranges, images, text

**Cons:**
- ❌ Slightly larger bundle size
- ❌ Would need to migrate from Chart.js
- ❌ Learning curve for configuration

**Best For:**
- Professional dashboards
- Interactive exploration
- Medical/health monitoring

**Code Example:**
```javascript
annotations: {
    points: [{
        x: new Date('2024-01-15 14:23:45').getTime(),
        y: 45,
        marker: {
            size: 8,
            fillColor: '#FF4560',
            strokeColor: '#fff'
        },
        label: {
            text: '🚨 Fall Detected',
            style: {
                background: '#FF4560',
                color: '#fff'
            }
        }
    }],
    xaxis: [{
        x: new Date('2024-01-15 22:00:00').getTime(),
        x2: new Date('2024-01-16 06:30:00').getTime(),
        fillColor: '#B3F7CA',
        opacity: 0.3,
        label: {
            text: 'Sleep Period'
        }
    }]
}
```

**Installation:**
```html
<script src="https://cdn.jsdelivr.net/npm/apexcharts"></script>
```

---

### 3. Plotly.js

**Pros:**
- ✅ Extremely powerful annotation system
- ✅ Scientific-grade visualizations
- ✅ Interactive by default
- ✅ 3D support (if needed)
- ✅ Export to PNG/SVG
- ✅ Excellent for data exploration
- ✅ Supports: shapes, annotations, range sliders

**Cons:**
- ❌ Large bundle size (~3MB)
- ❌ Heavier than Chart.js
- ❌ Can be overkill for simple dashboards

**Best For:**
- Data-heavy applications
- Scientific/medical analysis
- Advanced interactivity

**Code Example:**
```javascript
layout: {
    annotations: [
        {
            x: '2024-01-15 14:23:45',
            y: 45,
            text: '🚨 Fall Detected',
            showarrow: true,
            arrowhead: 2,
            ax: 0,
            ay: -40,
            bgcolor: 'rgba(255, 69, 96, 0.8)',
            font: { color: 'white' }
        }
    ],
    shapes: [
        {
            type: 'rect',
            x0: '2024-01-15 22:00:00',
            x1: '2024-01-16 06:30:00',
            y0: 0,
            y1: 100,
            fillcolor: 'rgba(99, 102, 241, 0.2)',
            line: { width: 0 }
        }
    ]
}
```

**Installation:**
```html
<script src="https://cdn.plot.ly/plotly-2.27.0.min.js"></script>
```

---

### 4. vis.js Timeline

**Pros:**
- ✅ Specifically designed for timelines
- ✅ Event-oriented view
- ✅ Built-in zooming, scrolling
- ✅ Grouping support
- ✅ Perfect for event tracking
- ✅ Custom item templates
- ✅ Range bars, points, background items

**Cons:**
- ❌ Different mental model than line charts
- ❌ Not great for continuous data
- ❌ Would replace, not complement Chart.js

**Best For:**
- Event timelines (like Google Calendar)
- Gantt-like views
- Discrete event tracking

**Code Example:**
```javascript
var items = new vis.DataSet([
    {
        id: 1,
        content: '🚨 Fall Detected',
        start: '2024-01-15 14:23:45',
        type: 'point',
        className: 'fall-event'
    },
    {
        id: 2,
        content: '😴 Sleep Period',
        start: '2024-01-15 22:00:00',
        end: '2024-01-16 06:30:00',
        type: 'range',
        className: 'sleep-period'
    }
]);

var timeline = new vis.Timeline(container, items, options);
```

**Installation:**
```html
<script src="https://unpkg.com/vis-timeline@latest/standalone/umd/vis-timeline-graph2d.min.js"></script>
```

---

### 5. D3.js

**Pros:**
- ✅ Ultimate flexibility
- ✅ Completely custom visualizations
- ✅ Publication-quality graphics
- ✅ Full control over everything
- ✅ Can create exactly what you want

**Cons:**
- ❌ Steep learning curve
- ❌ Lots of code for basic features
- ❌ Time-consuming to implement
- ❌ Need to build everything yourself

**Best For:**
- Custom, unique visualizations
- When standard libraries can't do what you need
- Long-term projects with development resources

**Code Example:**
```javascript
// D3 is very low-level, requires ~100+ lines for a basic annotated chart
svg.append("line")
    .attr("x1", xScale(new Date("2024-01-15 14:23:45")))
    .attr("x2", xScale(new Date("2024-01-15 14:23:45")))
    .attr("y1", 0)
    .attr("y2", height)
    .style("stroke", "red")
    .style("stroke-width", 2);

svg.append("text")
    .attr("x", xScale(new Date("2024-01-15 14:23:45")))
    .attr("y", 20)
    .text("🚨 Fall Detected");
```

**Installation:**
```html
<script src="https://d3js.org/d3.v7.min.js"></script>
```

---

## Feature Comparison Matrix

| Feature | Chart.js + Plugin | ApexCharts | Plotly.js | vis.js | D3.js |
|---------|-------------------|------------|-----------|--------|-------|
| **Ease of Use** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐ |
| **Bundle Size** | 📦 Small (200KB) | 📦 Medium (400KB) | 📦 Large (3MB) | 📦 Medium (500KB) | 📦 Medium (300KB) |
| **Annotation Types** | 7 types | 6 types | 10+ types | 5 types | Unlimited |
| **Real-time Updates** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Interactivity** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Documentation** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Mobile Friendly** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| **Learning Curve** | Low | Medium | Medium | Medium | High |
| **Implementation Time** | 1-2 hours | 1 day | 1 day | 2-3 hours | 1 week+ |

---

## Recommendation for moveOmeter

### Phase 1: Start with Chart.js Annotation Plugin (Now)
**Why:**
- Already integrated
- Fast implementation
- Handles 90% of your needs
- Lightweight

**What to add:**
1. Fall event markers (vertical lines)
2. Sleep period shading (boxes)
3. Activity threshold lines
4. Apnea event points
5. Medication/schedule markers

**See:** `timeline_annotations_example.js` for ready-to-use code

### Phase 2: Consider ApexCharts (Future Enhancement)
**Why:**
- More professional appearance
- Better mobile interactions
- Advanced zooming/panning
- Easier complex annotations

**When:**
- If users request more interactivity
- If you need synchronized zoom across multiple charts
- If medical certification requires higher-grade visualizations

### Phase 3: vis.js Timeline (Optional Supplementary View)
**Why:**
- Provides an alternate "event log" view
- Shows discrete events clearly
- Good for caregiver review

**When:**
- As a complementary view (not replacement)
- For detailed event history page
- For incident reports

---

## Implementation Guide (Chart.js Annotations)

### Step 1: Add Plugin (Done ✅)
```html
<script src="https://cdn.jsdelivr.net/npm/chartjs-plugin-annotation@3.0.1"></script>
```

### Step 2: Update Timeline Chart Configuration

In `dashboard.js`, modify the `charts.timeline12Hour` initialization:

```javascript
charts.timeline12Hour = new Chart(document.getElementById('timeline12Hour'), {
    type: 'line',
    data: { /* existing data */ },
    options: {
        // ... existing options ...
        plugins: {
            annotation: {
                annotations: {}  // Will be populated dynamically
            }
        }
    }
});
```

### Step 3: Create Event Detection Function

```javascript
function detectAndAnnotateEvents(data) {
    const annotations = {};

    data.forEach((point, index) => {
        // Fall detection
        if (point.fall_state > 0) {
            annotations[`fall_${index}`] = {
                type: 'line',
                xMin: point.timestamp,
                xMax: point.timestamp,
                borderColor: 'rgb(239, 68, 68)',
                borderWidth: 3,
                label: {
                    display: true,
                    content: '🚨 Fall',
                    backgroundColor: 'rgba(239, 68, 68, 0.9)',
                    color: 'white'
                }
            };
        }

        // Apnea events
        if (point.composite_apnea_events > 0) {
            annotations[`apnea_${index}`] = {
                type: 'point',
                xValue: point.timestamp,
                yValue: point.activityLevel,
                backgroundColor: 'rgb(220, 38, 38)',
                radius: 7,
                label: {
                    display: true,
                    content: `⚠️ Apnea (${point.composite_apnea_events})`
                }
            };
        }

        // Low activity periods
        if (point.activityLevel < 10 && point.human_existence > 0) {
            // Could indicate fall or medical issue
            annotations[`lowactivity_${index}`] = {
                type: 'point',
                xValue: point.timestamp,
                yValue: point.activityLevel,
                backgroundColor: 'rgb(251, 146, 60)',
                radius: 5
            };
        }
    });

    return annotations;
}
```

### Step 4: Update Timeline with Annotations

```javascript
function update12HourTimeline() {
    if (timeline12HourBuffer.length === 0) return;

    // ... existing code for labels and data ...

    // Detect and add annotations
    const annotations = detectAndAnnotateEvents(timeline12HourBuffer);
    charts.timeline12Hour.options.plugins.annotation.annotations = annotations;

    charts.timeline12Hour.update('none');
}
```

### Step 5: Add Sleep Period Detection

```javascript
function detectSleepPeriods(data) {
    const sleepAnnotations = {};
    let sleepStart = null;
    const sleepThreshold = 20;

    data.forEach((point, index) => {
        if (point.activityLevel < sleepThreshold && !sleepStart) {
            sleepStart = point.timestamp;
        } else if (point.activityLevel >= sleepThreshold && sleepStart) {
            sleepAnnotations[`sleep_${index}`] = {
                type: 'box',
                xMin: sleepStart,
                xMax: point.timestamp,
                backgroundColor: 'rgba(99, 102, 241, 0.15)',
                borderColor: 'rgba(99, 102, 241, 0.5)',
                borderWidth: 1,
                label: {
                    display: true,
                    content: '😴 Sleep',
                    position: 'center'
                }
            };
            sleepStart = null;
        }
    });

    return sleepAnnotations;
}
```

---

## Annotation Types Available

### Chart.js Annotation Plugin

1. **Line** - Vertical/horizontal lines (thresholds, events)
2. **Box** - Shaded rectangles (time periods, zones)
3. **Point** - Individual markers (specific events)
4. **Ellipse** - Circular highlights
5. **Polygon** - Custom shapes
6. **Label** - Text annotations

### Styling Options

```javascript
{
    borderColor: 'rgb(255, 99, 132)',
    borderWidth: 2,
    borderDash: [6, 6],  // Dashed line
    backgroundColor: 'rgba(255, 99, 132, 0.25)',
    label: {
        display: true,
        content: 'Label text or emoji',
        position: 'start' | 'center' | 'end',
        backgroundColor: 'rgba(0, 0, 0, 0.8)',
        color: 'white',
        font: {
            size: 12,
            weight: 'bold',
            family: 'Arial'
        },
        padding: 6,
        borderRadius: 4
    }
}
```

---

## Next Steps

1. ✅ **Added annotation plugin to HTML**
2. 📝 **Copy code from `timeline_annotations_example.js`**
3. 🔧 **Integrate into `dashboard.js`**
4. 🧪 **Test with real data**
5. 🎨 **Customize colors/labels for your brand**
6. 📊 **Add more event types as needed**

The code examples are ready to use - just copy the relevant sections and adapt the event detection logic to your data structure!
