// Admin Panel JavaScript

// Initialize Supabase client
const { createClient } = window.supabase;
const db = createClient(SUPABASE_CONFIG.url, SUPABASE_CONFIG.anonKey);

// State
let allUsers = [];
let allDevices = [];
let selectedDeviceId = null;
let editingUserId = null;

// Check admin/employee role
if (window.currentUser && !['admin', 'employee'].includes(window.currentUser.role)) {
    alert('Access denied. Admin or Employee privileges required.');
    window.location.href = 'index.html';
}

// Initialize on load
document.addEventListener('DOMContentLoaded', () => {
    console.log('Admin panel initializing...');

    // Set up tab switching
    const tabs = document.querySelectorAll('.admin-tab');
    tabs.forEach(tab => {
        tab.addEventListener('click', () => switchTab(tab.dataset.tab));
    });

    // Set up search and filter listeners
    setupSearchAndFilters();

    // Load initial data
    loadUsers();
    loadDevices();
    loadAuditLog();
    loadAuditUserFilter();

    // Dashboard button
    const dashboardBtn = document.getElementById('dashboard-btn');
    if (dashboardBtn) {
        dashboardBtn.addEventListener('click', () => {
            window.location.href = 'index.html';
        });
    }
});

// ============================================
// TAB SWITCHING
// ============================================

function switchTab(tabName) {
    // Update active tab button
    document.querySelectorAll('.admin-tab').forEach(t => t.classList.remove('active'));
    document.querySelector(`[data-tab="${tabName}"]`).classList.add('active');

    // Show correct content
    document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
    document.getElementById(`${tabName}-tab`).classList.add('active');

    // Load data for tab if needed
    if (tabName === 'users') {
        loadUsers();
    } else if (tabName === 'devices') {
        loadDevices();
    } else if (tabName === 'audit') {
        loadAuditLog();
    }
}

// ============================================
// ALERT MESSAGES
// ============================================

function showAlert(message, type = 'error') {
    const alertContainer = document.getElementById('alert-container');
    const alertClass = type === 'success' ? 'alert-success' : type === 'info' ? 'alert-info' : 'alert-error';

    alertContainer.innerHTML = `<div class="alert ${alertClass}">${message}</div>`;

    // Auto-dismiss after 5 seconds
    setTimeout(() => {
        alertContainer.innerHTML = '';
    }, 5000);

    // Scroll to top
    window.scrollTo({ top: 0, behavior: 'smooth' });
}

// ============================================
// USER MANAGEMENT
// ============================================

async function loadUsers() {
    const container = document.getElementById('users-table-container');
    container.innerHTML = '<div class="loading">Loading users</div>';

    try {
        const { data: users, error } = await db
            .from('user_profiles')
            .select('*')
            .order('created_at', { ascending: false });

        if (error) throw error;

        allUsers = users;
        renderUsersTable(users);
    } catch (error) {
        console.error('Error loading users:', error);
        container.innerHTML = '<div class="empty-state"><div class="empty-state-icon">⚠️</div><p>Failed to load users</p></div>';
        showAlert('Failed to load users: ' + error.message);
    }
}

function renderUsersTable(users) {
    const container = document.getElementById('users-table-container');

    if (users.length === 0) {
        container.innerHTML = '<div class="empty-state"><div class="empty-state-icon">👥</div><p>No users found</p></div>';
        return;
    }

    const roleIcons = {
        'admin': '👑',
        'employee': '👔',
        'caretaker': '🤝',
        'caretakee': '👤'
    };

    const roleLabels = {
        'admin': 'Admin',
        'employee': 'Employee',
        'caretaker': 'Caretaker',
        'caretakee': 'Resident'
    };

    const table = `
        <table class="data-table">
            <thead>
                <tr>
                    <th>Name</th>
                    <th>Email</th>
                    <th>Role</th>
                    <th>Status</th>
                    <th>Last Login</th>
                    <th>Actions</th>
                </tr>
            </thead>
            <tbody>
                ${users.map(user => `
                    <tr>
                        <td><strong>${escapeHtml(user.full_name)}</strong></td>
                        <td>${escapeHtml(user.email)}</td>
                        <td>
                            <span class="role-badge role-${user.role}">
                                ${roleIcons[user.role] || ''} ${roleLabels[user.role] || user.role}
                            </span>
                        </td>
                        <td>
                            <span class="status-badge status-${user.is_active ? 'active' : 'inactive'}">
                                ${user.is_active ? 'Active' : 'Inactive'}
                            </span>
                        </td>
                        <td>${user.last_login ? formatDate(user.last_login) : 'Never'}</td>
                        <td>
                            <div class="action-buttons">
                                <button class="icon-btn" onclick="openUserModal('${user.id}')" title="Edit">✏️</button>
                                <button class="icon-btn" onclick="toggleUserStatus('${user.id}', ${user.is_active})" title="${user.is_active ? 'Deactivate' : 'Activate'}">
                                    ${user.is_active ? '🔒' : '🔓'}
                                </button>
                            </div>
                        </td>
                    </tr>
                `).join('')}
            </tbody>
        </table>
    `;

    container.innerHTML = table;
}

function openUserModal(userId = null) {
    if (!userId) {
        showAlert('To create new users, direct them to the registration page. You can then assign their role here.', 'info');
        return;
    }

    const modal = document.getElementById('userModal');
    const form = document.getElementById('userForm');
    const title = document.getElementById('user-modal-title');
    const passwordGroup = document.getElementById('password-group');
    const passwordInput = document.getElementById('user-password');

    // Reset form
    form.reset();
    editingUserId = userId;
    document.getElementById('user-id').value = userId;
    document.getElementById('user-active').checked = true;

    // Edit mode only
    title.textContent = 'Edit User';
    passwordGroup.style.display = 'block';
    passwordGroup.querySelector('label').innerHTML = 'Password <small style="color: #999;">(leave blank to keep current)</small>';
    passwordInput.required = false;
    passwordInput.value = ''; // Clear password field

    // Load user data
    const user = allUsers.find(u => u.id === userId);
    if (user) {
        document.getElementById('user-name').value = user.full_name;
        document.getElementById('user-email').value = user.email;
        document.getElementById('user-role').value = user.role;
        document.getElementById('user-active').checked = user.is_active;
    }

    modal.classList.add('active');
}

function closeUserModal() {
    document.getElementById('userModal').classList.remove('active');
    editingUserId = null;
}

async function saveUser(event) {
    event.preventDefault();

    const userId = document.getElementById('user-id').value;
    const name = document.getElementById('user-name').value;
    const email = document.getElementById('user-email').value;
    const role = document.getElementById('user-role').value;
    const password = document.getElementById('user-password').value;
    const isActive = document.getElementById('user-active').checked;

    if (!userId) {
        showAlert('Cannot create users directly. Use the registration page.', 'error');
        return;
    }

    const saveBtn = document.getElementById('save-user-btn');
    saveBtn.disabled = true;
    saveBtn.textContent = 'Saving...';

    try {
        // Update existing user profile
        const updates = {
            full_name: name,
            email: email,
            role: role,
            is_active: isActive
        };

        const { error } = await db
            .from('user_profiles')
            .update(updates)
            .eq('id', userId);

        if (error) throw error;

        // Check if password was provided
        if (password && password.trim() !== '') {
            showAlert('User updated! Note: Password changes require a backend endpoint to implement.', 'info');
            console.log('Password change requested but not implemented - requires Auth Admin API');
        } else {
            showAlert('User updated successfully!', 'success');
        }

        await logAudit('update_user', 'user_profile', userId, true);

        closeUserModal();
        loadUsers();
    } catch (error) {
        console.error('Error saving user:', error);
        showAlert('Failed to save user: ' + error.message);
        await logAudit('update_user', 'user_profile', userId, false, error.message);
    } finally {
        saveBtn.disabled = false;
        saveBtn.textContent = 'Save User';
    }
}

async function toggleUserStatus(userId, currentStatus) {
    const action = currentStatus ? 'deactivate' : 'activate';

    if (!confirm(`Are you sure you want to ${action} this user?`)) {
        return;
    }

    try {
        const { error } = await db
            .from('user_profiles')
            .update({ is_active: !currentStatus })
            .eq('id', userId);

        if (error) throw error;

        showAlert(`User ${action}d successfully!`, 'success');
        await logAudit(action + '_user', 'user_profile', userId, true);
        loadUsers();
    } catch (error) {
        console.error('Error toggling user status:', error);
        showAlert('Failed to update user status: ' + error.message);
        await logAudit(action + '_user', 'user_profile', userId, false, error.message);
    }
}

// ============================================
// DEVICE ACCESS MANAGEMENT
// ============================================

async function loadDevices() {
    const container = document.getElementById('devices-list-container');
    container.innerHTML = '<div class="loading">Loading devices</div>';

    try {
        const { data: devices, error } = await db
            .from('moveometers')
            .select('device_id, location_name, device_status')
            .order('device_id');

        if (error) throw error;

        allDevices = devices;
        renderDevicesList(devices);
    } catch (error) {
        console.error('Error loading devices:', error);
        container.innerHTML = '<div class="empty-state"><div class="empty-state-icon">⚠️</div><p>Failed to load devices</p></div>';
        showAlert('Failed to load devices: ' + error.message);
    }
}

function renderDevicesList(devices) {
    const container = document.getElementById('devices-list-container');

    if (devices.length === 0) {
        container.innerHTML = '<div class="empty-state"><div class="empty-state-icon">📱</div><p>No devices found</p></div>';
        return;
    }

    const html = devices.map(device => `
        <div class="device-list-item" onclick="selectDevice('${device.device_id}')">
            <div class="device-info">
                <div>
                    <div class="device-name">${escapeHtml(device.device_id)}</div>
                    <div class="device-location">${escapeHtml(device.location_name || 'No location')}</div>
                </div>
                <div class="access-count" id="access-count-${device.device_id}">
                    <span class="loading"></span>
                </div>
            </div>
        </div>
    `).join('');

    container.innerHTML = html;

    // Load access counts for each device
    devices.forEach(device => loadAccessCount(device.device_id));
}

async function loadAccessCount(deviceId) {
    try {
        const { count, error } = await db
            .from('device_access')
            .select('*', { count: 'exact', head: true })
            .eq('device_id', deviceId);

        if (error) throw error;

        const element = document.getElementById(`access-count-${deviceId}`);
        if (element) {
            element.textContent = `${count} user${count !== 1 ? 's' : ''}`;
        }
    } catch (error) {
        console.error('Error loading access count:', error);
    }
}

function selectDevice(deviceId) {
    selectedDeviceId = deviceId;

    // Update UI
    document.querySelectorAll('.device-list-item').forEach(item => {
        item.classList.remove('selected');
    });
    event.currentTarget.classList.add('selected');

    // Update header
    const device = allDevices.find(d => d.device_id === deviceId);
    document.getElementById('selected-device-name').textContent = device ? device.device_id : deviceId;

    // Enable grant access button
    document.getElementById('grant-access-btn').disabled = false;

    // Load access for this device
    loadDeviceAccess(deviceId);
}

async function loadDeviceAccess(deviceId) {
    const container = document.getElementById('device-access-container');
    container.innerHTML = '<div class="loading">Loading access</div>';

    try {
        const { data: accessList, error } = await db
            .from('device_access')
            .select(`
                *,
                user_profiles!user_id (
                    full_name,
                    email,
                    role
                )
            `)
            .eq('device_id', deviceId)
            .order('created_at', { ascending: false });

        if (error) throw error;

        renderDeviceAccess(accessList);
    } catch (error) {
        console.error('Error loading device access:', error);
        container.innerHTML = '<div class="empty-state"><div class="empty-state-icon">⚠️</div><p>Failed to load access</p></div>';
    }
}

function renderDeviceAccess(accessList) {
    const container = document.getElementById('device-access-container');

    if (accessList.length === 0) {
        container.innerHTML = '<div class="empty-state"><div class="empty-state-icon">🔒</div><p>No users have access yet</p></div>';
        return;
    }

    const html = accessList.map(access => `
        <div class="access-list-item">
            <div class="access-info">
                <div class="access-user">
                    <div class="access-name">${escapeHtml(access.user_profiles?.full_name || 'Unknown')}</div>
                    <div class="access-level">${access.access_level} access • Granted ${formatDate(access.created_at)}</div>
                </div>
                <button class="icon-btn" onclick="revokeAccess('${access.id}')" title="Revoke Access">🗑️</button>
            </div>
        </div>
    `).join('');

    container.innerHTML = html;
}

function openAccessModal() {
    if (!selectedDeviceId) {
        showAlert('Please select a device first');
        return;
    }

    const modal = document.getElementById('accessModal');
    const userSelect = document.getElementById('access-user');

    // Populate user dropdown
    userSelect.innerHTML = '<option value="">Select user...</option>';
    allUsers.filter(u => u.is_active).forEach(user => {
        userSelect.innerHTML += `<option value="${user.id}">${escapeHtml(user.full_name)} (${escapeHtml(user.email)})</option>`;
    });

    // Reset form
    document.getElementById('accessForm').reset();

    modal.classList.add('active');
}

function closeAccessModal() {
    document.getElementById('accessModal').classList.remove('active');
}

async function saveAccess(event) {
    event.preventDefault();

    const userId = document.getElementById('access-user').value;
    const accessLevel = document.getElementById('access-level').value;
    const notes = document.getElementById('access-notes').value;

    try {
        const { error } = await db
            .from('device_access')
            .insert({
                user_id: userId,
                device_id: selectedDeviceId,
                access_level: accessLevel,
                granted_by: window.currentUser.id,
                notes: notes || null
            });

        if (error) throw error;

        showAlert('Access granted successfully!', 'success');
        await logAudit('grant_access', 'device_access', selectedDeviceId, true);

        closeAccessModal();
        loadDeviceAccess(selectedDeviceId);
        loadAccessCount(selectedDeviceId);
    } catch (error) {
        console.error('Error granting access:', error);
        showAlert('Failed to grant access: ' + error.message);
        await logAudit('grant_access', 'device_access', selectedDeviceId, false, error.message);
    }
}

async function revokeAccess(accessId) {
    if (!confirm('Are you sure you want to revoke this access?')) {
        return;
    }

    try {
        const { error } = await db
            .from('device_access')
            .delete()
            .eq('id', accessId);

        if (error) throw error;

        showAlert('Access revoked successfully!', 'success');
        await logAudit('revoke_access', 'device_access', selectedDeviceId, true);

        loadDeviceAccess(selectedDeviceId);
        loadAccessCount(selectedDeviceId);
    } catch (error) {
        console.error('Error revoking access:', error);
        showAlert('Failed to revoke access: ' + error.message);
        await logAudit('revoke_access', 'device_access', selectedDeviceId, false, error.message);
    }
}

// ============================================
// AUDIT LOG
// ============================================

async function loadAuditLog() {
    const container = document.getElementById('audit-table-container');
    container.innerHTML = '<div class="loading">Loading audit log</div>';

    try {
        // Get filter values
        const userFilter = document.getElementById('audit-user-filter')?.value || '';
        const actionFilter = document.getElementById('audit-action-filter')?.value || '';
        const statusFilter = document.getElementById('audit-status-filter')?.value || '';
        const dateFilter = document.getElementById('audit-date-filter')?.value || '24h';

        // Build query
        let query = db
            .from('audit_log')
            .select(`
                *,
                user_profiles (
                    full_name,
                    email
                )
            `)
            .order('created_at', { ascending: false })
            .limit(100);

        // Apply filters
        if (userFilter) {
            query = query.eq('user_id', userFilter);
        }

        if (actionFilter) {
            query = query.eq('action', actionFilter);
        }

        if (statusFilter) {
            query = query.eq('success', statusFilter === 'success');
        }

        // Date filter
        if (dateFilter !== 'all') {
            const now = new Date();
            let startDate;

            if (dateFilter === '24h') {
                startDate = new Date(now.getTime() - 24 * 60 * 60 * 1000);
            } else if (dateFilter === '7d') {
                startDate = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
            } else if (dateFilter === '30d') {
                startDate = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
            }

            if (startDate) {
                query = query.gte('created_at', startDate.toISOString());
            }
        }

        const { data: logs, error } = await query;

        if (error) throw error;

        renderAuditTable(logs);
    } catch (error) {
        console.error('Error loading audit log:', error);
        container.innerHTML = '<div class="empty-state"><div class="empty-state-icon">⚠️</div><p>Failed to load audit log</p></div>';
        showAlert('Failed to load audit log: ' + error.message);
    }
}

function renderAuditTable(logs) {
    const container = document.getElementById('audit-table-container');

    if (logs.length === 0) {
        container.innerHTML = '<div class="empty-state"><div class="empty-state-icon">📋</div><p>No audit logs found</p></div>';
        return;
    }

    const table = `
        <table class="data-table">
            <thead>
                <tr>
                    <th>Timestamp</th>
                    <th>User</th>
                    <th>Action</th>
                    <th>Resource</th>
                    <th>Status</th>
                    <th>Error</th>
                </tr>
            </thead>
            <tbody>
                ${logs.map(log => `
                    <tr>
                        <td>${formatDateTime(log.created_at)}</td>
                        <td>${escapeHtml(log.user_profiles?.full_name || 'Unknown')}</td>
                        <td>${escapeHtml(log.action)}</td>
                        <td>
                            ${log.resource_type ? escapeHtml(log.resource_type) : '-'}
                            ${log.resource_id ? '<br><small>' + escapeHtml(log.resource_id) + '</small>' : ''}
                        </td>
                        <td>
                            <span class="status-badge status-${log.success ? 'active' : 'inactive'}">
                                ${log.success ? '✓ Success' : '✗ Failed'}
                            </span>
                        </td>
                        <td>${log.error_message ? '<small>' + escapeHtml(log.error_message) + '</small>' : '-'}</td>
                    </tr>
                `).join('')}
            </tbody>
        </table>
    `;

    container.innerHTML = table;
}

async function loadAuditUserFilter() {
    try {
        const { data: users, error } = await db
            .from('user_profiles')
            .select('id, full_name')
            .order('full_name');

        if (error) throw error;

        const select = document.getElementById('audit-user-filter');
        if (select) {
            users.forEach(user => {
                select.innerHTML += `<option value="${user.id}">${escapeHtml(user.full_name)}</option>`;
            });
        }
    } catch (error) {
        console.error('Error loading users for filter:', error);
    }
}

function exportAuditLog() {
    // Get current audit table data
    const table = document.querySelector('#audit-table-container table');
    if (!table) {
        showAlert('No data to export');
        return;
    }

    // Convert table to CSV
    const rows = Array.from(table.querySelectorAll('tr'));
    const csv = rows.map(row => {
        const cells = Array.from(row.querySelectorAll('th, td'));
        return cells.map(cell => {
            // Clean up cell text
            let text = cell.textContent.trim();
            text = text.replace(/\n/g, ' ').replace(/\s+/g, ' ');
            // Escape quotes
            text = text.replace(/"/g, '""');
            return `"${text}"`;
        }).join(',');
    }).join('\n');

    // Download
    const blob = new Blob([csv], { type: 'text/csv' });
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `audit-log-${new Date().toISOString().split('T')[0]}.csv`;
    a.click();
    window.URL.revokeObjectURL(url);

    showAlert('Audit log exported successfully!', 'success');
}

// ============================================
// SEARCH AND FILTERS
// ============================================

function setupSearchAndFilters() {
    // User search and filters
    const userSearch = document.getElementById('user-search');
    const roleFilter = document.getElementById('role-filter');
    const statusFilter = document.getElementById('status-filter');

    if (userSearch) {
        userSearch.addEventListener('input', filterUsers);
    }
    if (roleFilter) {
        roleFilter.addEventListener('change', filterUsers);
    }
    if (statusFilter) {
        statusFilter.addEventListener('change', filterUsers);
    }

    // Audit log filters
    const auditUserFilter = document.getElementById('audit-user-filter');
    const auditActionFilter = document.getElementById('audit-action-filter');
    const auditStatusFilter = document.getElementById('audit-status-filter');
    const auditDateFilter = document.getElementById('audit-date-filter');

    if (auditUserFilter) auditUserFilter.addEventListener('change', loadAuditLog);
    if (auditActionFilter) auditActionFilter.addEventListener('change', loadAuditLog);
    if (auditStatusFilter) auditStatusFilter.addEventListener('change', loadAuditLog);
    if (auditDateFilter) auditDateFilter.addEventListener('change', loadAuditLog);
}

function filterUsers() {
    const searchTerm = document.getElementById('user-search').value.toLowerCase();
    const roleFilter = document.getElementById('role-filter').value;
    const statusFilter = document.getElementById('status-filter').value;

    const filtered = allUsers.filter(user => {
        const matchesSearch = user.full_name.toLowerCase().includes(searchTerm) ||
                            user.email.toLowerCase().includes(searchTerm);
        const matchesRole = !roleFilter || user.role === roleFilter;
        const matchesStatus = !statusFilter ||
                            (statusFilter === 'active' && user.is_active) ||
                            (statusFilter === 'inactive' && !user.is_active);

        return matchesSearch && matchesRole && matchesStatus;
    });

    renderUsersTable(filtered);
}

// ============================================
// AUDIT LOGGING HELPER
// ============================================

async function logAudit(action, resourceType, resourceId, success, errorMessage = null) {
    try {
        await db.from('audit_log').insert({
            user_id: window.currentUser.id,
            action: action,
            resource_type: resourceType,
            resource_id: resourceId,
            ip_address: null,
            user_agent: navigator.userAgent,
            success: success,
            error_message: errorMessage
        });
    } catch (error) {
        console.error('Audit log error:', error);
    }
}

// ============================================
// UTILITY FUNCTIONS
// ============================================

function escapeHtml(text) {
    if (!text) return '';
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function formatDate(dateString) {
    if (!dateString) return 'Never';
    const date = new Date(dateString);
    const now = new Date();
    const diffMs = now - date;
    const diffMins = Math.floor(diffMs / 60000);
    const diffHours = Math.floor(diffMs / 3600000);
    const diffDays = Math.floor(diffMs / 86400000);

    if (diffMins < 1) return 'Just now';
    if (diffMins < 60) return `${diffMins}m ago`;
    if (diffHours < 24) return `${diffHours}h ago`;
    if (diffDays < 7) return `${diffDays}d ago`;

    return date.toLocaleDateString();
}

function formatDateTime(dateString) {
    if (!dateString) return 'Never';
    const date = new Date(dateString);
    return date.toLocaleString();
}
