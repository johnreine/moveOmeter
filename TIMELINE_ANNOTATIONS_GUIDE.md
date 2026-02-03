# Timeline Annotations User Guide

Complete guide for adding, managing, and viewing custom annotations on the 12-hour activity timeline.

## Overview

The annotation system allows caregivers and users to add custom notes, events, and reminders directly to the timeline. These annotations are stored in the database and displayed alongside auto-detected events like falls and apnea.

## Features

✅ **Custom Annotations** - Add any type of note or event
✅ **Rich Metadata** - Title, description, date, time, type, color, icon
✅ **Visual Timeline Display** - Annotations appear as markers on the 12-hour timeline
✅ **Edit & Delete** - Modify or remove annotations anytime
✅ **Auto-Detection Integration** - User annotations appear alongside system-detected events
✅ **Color Coding** - Customize colors for different event types
✅ **Emoji Icons** - Visual identifiers for quick recognition

## Database Setup

### 1. Create the Annotations Table

Execute the SQL migration in your Supabase database:

```bash
psql -h <your-supabase-host> -U postgres -d postgres -f database/create_annotations_table.sql
```

Or in Supabase SQL Editor:
- Go to Supabase Dashboard → SQL Editor
- Copy contents of `database/create_annotations_table.sql`
- Execute

### 2. Table Schema

```sql
timeline_annotations (
    id                   UUID PRIMARY KEY,
    device_id            TEXT NOT NULL,
    annotation_timestamp TIMESTAMPTZ NOT NULL,
    annotation_type      TEXT DEFAULT 'custom',
    title                TEXT NOT NULL,
    description          TEXT,
    color                TEXT DEFAULT '#667eea',
    icon                 TEXT DEFAULT '📝',
    created_at           TIMESTAMPTZ DEFAULT NOW(),
    updated_at           TIMESTAMPTZ DEFAULT NOW(),
    created_by           TEXT
)
```

## User Interface

### Adding an Annotation

1. **Click the floating '+' button** (bottom-right corner)
2. **Fill in the form:**
   - **Title** (required): Brief description (e.g., "Took blood pressure medication")
   - **Description** (optional): Additional details
   - **Date & Time** (required): When the event occurred
   - **Type**: Category from dropdown
   - **Color**: Choose a color for the marker
   - **Icon**: Select an emoji icon
3. **Click "Save Annotation"**

### Editing an Annotation

1. Open the annotation modal (click '+' button)
2. In the "Recent Annotations" list at the bottom, click the edit (✏️) icon
3. Modify the fields
4. Click "Save Annotation"

### Deleting an Annotation

1. Click edit (✏️) on the annotation
2. Click "Delete" button (appears when editing)
3. Confirm deletion

## Annotation Types

### Predefined Types

| Type | Icon | Suggested Use |
|------|------|---------------|
| **Custom Note** | 📝 | General notes and observations |
| **Medication** | 💊 | Medication taken, dosage changes |
| **Appointment** | 🏥 | Doctor visits, therapy sessions |
| **Meal** | 🍽️ | Meal times, dietary changes |
| **Activity** | 🏃 | Exercise, walks, physical therapy |
| **Symptom** | 🤒 | Pain, discomfort, health issues |
| **Fall (Manual)** | 🚨 | Manually recorded fall events |
| **Visitor** | 👥 | Family visits, caregiver check-ins |

### Custom Types

You can create your own annotation types by selecting "Custom Note" and using:
- Custom icons from the emoji picker
- Custom colors for the marker
- Descriptive titles

## Timeline Display

### How Annotations Appear

**User Annotations** (from this system):
- Displayed as **vertical dashed lines** on the timeline
- Color matches the annotation's color setting
- Shows icon + title in a label
- Positioned at the exact time of the event

**Auto-Detected Events** (from sensor):
- Falls: Red solid line with 🚨 icon
- Apnea: Red point marker with event count
- (More auto-detection coming soon)

### Visual Example

```
Timeline (12-hour view)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ┆         ●         ┆
  ┆ 💊 Medication   ⚠️ Apnea (2)
  ┆ 08:00 AM           14:23 PM
  ┆
8AM ────────── 2PM ────────── 8PM
```

## Common Use Cases

### 1. Medication Tracking

```
Title: Blood Pressure Medication
Type: Medication 💊
Time: 08:00 AM
Description: Lisinopril 10mg
Color: Blue
```

### 2. Doctor Appointments

```
Title: Cardiology Appointment
Type: Appointment 🏥
Time: 02:30 PM
Description: Dr. Smith - Follow-up
Color: Green
```

### 3. Fall Documentation

```
Title: Minor Fall in Bathroom
Type: Fall (Manual) 🚨
Time: 03:15 PM
Description: Lost balance, no injury
Color: Red
```

### 4. Daily Activities

```
Title: Morning Walk
Type: Activity 🏃
Time: 09:00 AM
Description: 15 minutes around block
Color: Orange
```

### 5. Symptom Tracking

```
Title: Headache Started
Type: Symptom 🤒
Time: 11:30 AM
Description: Mild, took aspirin
Color: Yellow
```

### 6. Visitor Log

```
Title: Daughter Visit
Type: Visitor 👥
Time: 04:00 PM
Description: 2 hour visit, had tea
Color: Purple
```

## Best Practices

### 1. Consistent Naming
Use consistent titles for recurring events:
- "Morning Medication" vs random descriptions
- "Physical Therapy" vs "PT" or "Therapy"

### 2. Color Coding
Establish a color scheme:
- Blue: Medications
- Green: Appointments
- Red: Health concerns
- Orange: Activities
- Yellow: Symptoms

### 3. Timely Entry
Add annotations soon after events occur for accuracy

### 4. Descriptive Details
Use the description field for:
- Dosages
- Duration
- Outcomes
- Next steps

### 5. Review Regularly
Periodically review annotations to identify patterns

## API Reference

### Load Annotations

```javascript
await loadUserAnnotations();
```
- Loads last 12 hours of annotations
- Updates timeline display
- Populates modal list

### Create Annotation

```javascript
const annotation = {
    device_id: 'ESP32C6_001',
    annotation_timestamp: '2024-01-15T14:30:00Z',
    annotation_type: 'medication',
    title: 'Blood Pressure Med',
    description: 'Lisinopril 10mg',
    color: '#3b82f6',
    icon: '💊'
};

await db.from('timeline_annotations').insert([annotation]);
```

### Update Annotation

```javascript
await db
    .from('timeline_annotations')
    .update({ title: 'Updated Title' })
    .eq('id', annotationId);
```

### Delete Annotation

```javascript
await db
    .from('timeline_annotations')
    .delete()
    .eq('id', annotationId);
```

## Troubleshooting

### Annotations Not Appearing

**Check:**
1. Database table exists (`timeline_annotations`)
2. RLS policies allow read access
3. Device ID matches (`ESP32C6_001`)
4. Timestamp is within last 12 hours
5. Browser console for errors

**Fix:**
```javascript
// Open browser console and run:
await loadUserAnnotations();
console.log(userAnnotations);
```

### Modal Won't Open

**Check:**
1. JavaScript loaded properly
2. No console errors
3. Modal HTML exists in index.html

**Fix:**
Refresh page and check browser console

### Save Button Not Working

**Check:**
1. Required fields filled (Title, Date, Time)
2. Valid date/time format
3. Database connection active

**Fix:**
- Fill all required fields
- Check network tab for failed requests
- Verify Supabase credentials

### Annotations Missing After Refresh

**Check:**
1. `loadUserAnnotations()` called on page load
2. Database query successful
3. Correct device_id filter

**Fix:**
```javascript
// Manually reload:
await loadUserAnnotations();
```

## Advanced Features

### Programmatic Annotation Creation

Create annotations from code (e.g., automatic medication reminders):

```javascript
async function createMedicationReminder(time, medication) {
    const annotation = {
        device_id: DASHBOARD_CONFIG.deviceId,
        annotation_timestamp: time,
        annotation_type: 'medication',
        title: `${medication} Due`,
        description: 'Medication reminder',
        color: '#3b82f6',
        icon: '💊'
    };

    await db.from('timeline_annotations').insert([annotation]);
    await loadUserAnnotations();
}
```

### Bulk Import

Import multiple annotations at once:

```javascript
const annotations = [
    { title: 'Breakfast', time: '08:00', type: 'meal', icon: '🍽️' },
    { title: 'Lunch', time: '12:00', type: 'meal', icon: '🍽️' },
    { title: 'Dinner', time: '18:00', type: 'meal', icon: '🍽️' }
];

const records = annotations.map(a => ({
    device_id: 'ESP32C6_001',
    annotation_timestamp: `2024-01-15T${a.time}:00Z`,
    annotation_type: a.type,
    title: a.title,
    icon: a.icon,
    color: '#f59e0b'
}));

await db.from('timeline_annotations').insert(records);
```

### Export Annotations

Export as CSV for reports:

```javascript
function exportAnnotationsToCsv() {
    const csv = userAnnotations.map(a =>
        `${a.annotation_timestamp},${a.title},${a.annotation_type},${a.description || ''}`
    ).join('\n');

    const blob = new Blob([csv], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'annotations.csv';
    a.click();
}
```

### Recurring Annotations

Create daily medication reminders:

```javascript
async function createRecurringAnnotations(days = 30) {
    const annotations = [];
    const now = new Date();

    for (let i = 0; i < days; i++) {
        const date = new Date(now);
        date.setDate(date.getDate() + i);
        date.setHours(8, 0, 0, 0);

        annotations.push({
            device_id: 'ESP32C6_001',
            annotation_timestamp: date.toISOString(),
            annotation_type: 'medication',
            title: 'Morning Medication Reminder',
            icon: '💊',
            color: '#3b82f6'
        });
    }

    await db.from('timeline_annotations').insert(annotations);
    console.log(`Created ${days} medication reminders`);
}
```

## Integration with Other Systems

### Export to Calendar

Convert annotations to iCal format:

```javascript
function exportToIcal() {
    const events = userAnnotations.map(a => {
        return `BEGIN:VEVENT
UID:${a.id}
DTSTAMP:${new Date(a.annotation_timestamp).toISOString()}
SUMMARY:${a.title}
DESCRIPTION:${a.description || ''}
END:VEVENT`;
    }).join('\n');

    const ical = `BEGIN:VCALENDAR
VERSION:2.0
${events}
END:VCALENDAR`;

    // Download .ics file
}
```

### Email Alerts

Send daily summary of annotations:

```javascript
async function emailDailySummary(email) {
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const { data } = await db
        .from('timeline_annotations')
        .select('*')
        .gte('annotation_timestamp', today.toISOString());

    // Format and send email
    const summary = data.map(a =>
        `${a.icon} ${a.title} at ${new Date(a.annotation_timestamp).toLocaleTimeString()}`
    ).join('\n');

    // Send via email service
}
```

## Future Enhancements

Planned features:
- 📱 Mobile app annotation entry
- 🔔 Annotation-based alerts and reminders
- 📊 Annotation analytics and reports
- 👥 Multi-user annotations with permissions
- 🔍 Search and filter annotations
- 📎 Attach photos or documents to annotations
- 🔄 Sync with external calendar systems
- 🗣️ Voice-to-text annotation entry

## Support

For issues or questions:
1. Check browser console for errors
2. Verify database table exists
3. Review this guide
4. Check network connectivity
5. Report bugs on GitHub

The annotation system is now ready to use! Click the '+' button to add your first annotation. 🎉
