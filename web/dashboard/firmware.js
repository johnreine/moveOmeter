// Initialize Supabase client
const { createClient } = window.supabase;
const db = createClient(SUPABASE_CONFIG.url, SUPABASE_CONFIG.anonKey);

let selectedFile = null;
let uploadedFileUrl = null;

// Initialize page
document.addEventListener('DOMContentLoaded', () => {
    loadDeviceStatus();
    loadFirmwareHistory();
    setupFileInput();

    // Refresh device status every 10 seconds
    setInterval(loadDeviceStatus, 10000);
});

// Setup file input handler
function setupFileInput() {
    const fileInput = document.getElementById('firmware-file');
    fileInput.addEventListener('change', (e) => {
        selectedFile = e.target.files[0];
        if (selectedFile) {
            document.getElementById('file-name').textContent = `Selected: ${selectedFile.name} (${formatFileSize(selectedFile.size)})`;
            document.getElementById('publish-button').disabled = false;

            // Auto-extract version from filename if possible
            const versionMatch = selectedFile.name.match(/v?(\d+\.\d+\.\d+)/);
            if (versionMatch) {
                document.getElementById('version').value = versionMatch[1];
            }
        }
    });
}

// Load device status
async function loadDeviceStatus() {
    try {
        const { data, error } = await db
            .from('moveometers')
            .select('firmware_version, ota_status, last_ota_check, last_ota_update, ota_error')
            .eq('device_id', 'ESP32C6_001')
            .single();

        if (error) throw error;

        if (data) {
            document.getElementById('current-version').textContent = data.firmware_version || '1.0.0';

            const statusBadge = document.getElementById('ota-status');
            statusBadge.textContent = data.ota_status || 'idle';
            statusBadge.className = 'status-badge status-' + (data.ota_status || 'idle');

            document.getElementById('last-check').textContent =
                data.last_ota_check ? formatTimestamp(data.last_ota_check) : 'Never';

            document.getElementById('last-update').textContent =
                data.last_ota_update ? formatTimestamp(data.last_ota_update) : 'Never';
        }
    } catch (error) {
        console.error('Error loading device status:', error);
    }
}

// Load firmware history
async function loadFirmwareHistory() {
    try {
        const { data, error } = await db
            .from('firmware_updates')
            .select('*')
            .eq('device_model', 'ESP32C6_MOVEOMETER')
            .order('created_at', { ascending: false });

        if (error) throw error;

        const listElement = document.getElementById('firmware-list');

        if (!data || data.length === 0) {
            listElement.innerHTML = '<p style="color: #666;">No firmware versions found</p>';
            return;
        }

        listElement.innerHTML = data.map(firmware => `
            <div class="firmware-item">
                <div class="firmware-info">
                    <h3>Version ${firmware.version}</h3>
                    <p><strong>Released:</strong> ${formatTimestamp(firmware.created_at)}</p>
                    <p><strong>File Size:</strong> ${formatFileSize(firmware.file_size_bytes || 0)}</p>
                    ${firmware.mandatory ? '<p style="color: #dc3545;"><strong>⚠️ Mandatory Update</strong></p>' : ''}
                    ${firmware.release_notes ? `<p><strong>Notes:</strong> ${firmware.release_notes}</p>` : ''}
                    ${firmware.md5_checksum ? `<p style="font-size: 12px; color: #999;"><strong>MD5:</strong> ${firmware.md5_checksum}</p>` : ''}
                </div>
                <div class="firmware-actions">
                    <button onclick="deleteFirmware('${firmware.id}', '${firmware.version}')">Delete</button>
                </div>
            </div>
        `).join('');
    } catch (error) {
        console.error('Error loading firmware history:', error);
        document.getElementById('firmware-list').innerHTML =
            '<p style="color: #dc3545;">Error loading firmware history</p>';
    }
}

// Publish firmware
async function publishFirmware() {
    const version = document.getElementById('version').value.trim();
    const releaseNotes = document.getElementById('release-notes').value.trim();
    const mandatory = document.getElementById('mandatory').checked;

    if (!selectedFile) {
        showAlert('Please select a firmware file', 'error');
        return;
    }

    if (!version) {
        showAlert('Please enter a version number', 'error');
        return;
    }

    if (!/^\d+\.\d+\.\d+$/.test(version)) {
        showAlert('Version must be in format X.Y.Z (e.g., 1.0.1)', 'error');
        return;
    }

    try {
        document.getElementById('publish-button').disabled = true;
        document.getElementById('publish-button').textContent = 'Uploading...';

        // Show progress bar
        const progressBar = document.getElementById('upload-progress');
        progressBar.style.display = 'block';
        updateProgress(0);

        // Upload file to Supabase Storage
        const fileName = `moveometer_v${version}.bin`;
        const filePath = `firmware/${fileName}`;

        updateProgress(20);
        showAlert('Uploading firmware file...', 'info');

        const { data: uploadData, error: uploadError } = await db.storage
            .from('firmware')
            .upload(filePath, selectedFile, {
                cacheControl: '3600',
                upsert: true
            });

        if (uploadError) throw uploadError;

        updateProgress(60);
        showAlert('Generating download URL...', 'info');

        // Get public URL
        const { data: urlData } = db.storage
            .from('firmware')
            .getPublicUrl(filePath);

        uploadedFileUrl = urlData.publicUrl;
        updateProgress(80);

        // Calculate MD5 checksum (simplified - in production use proper crypto)
        const md5 = await calculateMD5(selectedFile);

        showAlert('Creating firmware record...', 'info');

        // Insert firmware record
        const { error: insertError } = await db
            .from('firmware_updates')
            .insert({
                version: version,
                device_model: 'ESP32C6_MOVEOMETER',
                download_url: uploadedFileUrl,
                file_size_bytes: selectedFile.size,
                md5_checksum: md5,
                release_notes: releaseNotes || null,
                mandatory: mandatory,
                created_by: 'web_admin'
            });

        if (insertError) throw insertError;

        updateProgress(100);
        showAlert(`Firmware version ${version} published successfully! Device will update within 1 hour.`, 'success');

        // Reset form
        selectedFile = null;
        uploadedFileUrl = null;
        document.getElementById('firmware-file').value = '';
        document.getElementById('file-name').textContent = '';
        document.getElementById('version').value = '';
        document.getElementById('release-notes').value = '';
        document.getElementById('mandatory').checked = false;
        document.getElementById('publish-button').disabled = true;
        document.getElementById('publish-button').textContent = 'Publish Firmware';

        // Reload firmware history
        loadFirmwareHistory();

        // Hide progress bar after 2 seconds
        setTimeout(() => {
            progressBar.style.display = 'none';
        }, 2000);

    } catch (error) {
        console.error('Error publishing firmware:', error);
        showAlert('Failed to publish firmware: ' + error.message, 'error');
        document.getElementById('publish-button').disabled = false;
        document.getElementById('publish-button').textContent = 'Publish Firmware';
    }
}

// Delete firmware
async function deleteFirmware(id, version) {
    if (!confirm(`Are you sure you want to delete firmware version ${version}?`)) {
        return;
    }

    try {
        const { error } = await db
            .from('firmware_updates')
            .delete()
            .eq('id', id);

        if (error) throw error;

        showAlert(`Firmware version ${version} deleted successfully`, 'success');
        loadFirmwareHistory();
    } catch (error) {
        console.error('Error deleting firmware:', error);
        showAlert('Failed to delete firmware: ' + error.message, 'error');
    }
}

// Calculate MD5 checksum (simplified)
async function calculateMD5(file) {
    const buffer = await file.arrayBuffer();
    const hashBuffer = await crypto.subtle.digest('SHA-256', buffer);
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
}

// Update progress bar
function updateProgress(percent) {
    const fill = document.getElementById('progress-fill');
    fill.style.width = percent + '%';
    fill.textContent = percent + '%';
}

// Show alert message
function showAlert(message, type) {
    const container = document.getElementById('alert-container');
    const alert = document.createElement('div');
    alert.className = `alert alert-${type}`;
    alert.textContent = message;
    container.innerHTML = '';
    container.appendChild(alert);

    if (type === 'success' || type === 'info') {
        setTimeout(() => {
            alert.remove();
        }, 5000);
    }
}

// Format file size
function formatFileSize(bytes) {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return Math.round(bytes / Math.pow(k, i) * 100) / 100 + ' ' + sizes[i];
}

// Format timestamp
function formatTimestamp(timestamp) {
    const date = new Date(timestamp);
    return date.toLocaleString('en-US', {
        year: 'numeric',
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
    });
}
