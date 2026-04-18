// Authentication JavaScript
// Create Supabase client with error handling
let authClient;
try {
    if (!window.supabase) {
        throw new Error('Supabase library failed to load');
    }
    const { createClient } = window.supabase;
    authClient = createClient(SUPABASE_CONFIG.url, SUPABASE_CONFIG.anonKey);
    console.log('✅ Supabase client initialized');
} catch (error) {
    console.error('❌ Failed to initialize Supabase:', error);
    document.addEventListener('DOMContentLoaded', () => {
        const alertContainer = document.getElementById('alert-container');
        if (alertContainer) {
            alertContainer.innerHTML = '<div class="alert alert-error">Failed to load authentication system. Please refresh the page.</div>';
        }
    });
}

// UI Elements
const loginForm = document.getElementById('login-form');
const registerForm = document.getElementById('register-form');
const resetForm = document.getElementById('reset-form');
const alertContainer = document.getElementById('alert-container');
const tabs = document.querySelectorAll('.tab');

// Tab switching
tabs.forEach(tab => {
    tab.addEventListener('click', () => {
        const tabName = tab.dataset.tab;
        switchTab(tabName);
    });
});

function switchTab(tabName) {
    // Update active tab
    tabs.forEach(t => t.classList.remove('active'));
    document.querySelector(`[data-tab="${tabName}"]`).classList.add('active');

    // Show correct form
    loginForm.classList.add('hidden');
    registerForm.classList.add('hidden');
    resetForm.classList.add('hidden');

    if (tabName === 'login') {
        loginForm.classList.remove('hidden');
    } else if (tabName === 'register') {
        registerForm.classList.remove('hidden');
    }

    clearAlert();
}

// Forgot password link
document.getElementById('forgot-password-link').addEventListener('click', (e) => {
    e.preventDefault();
    loginForm.classList.add('hidden');
    resetForm.classList.remove('hidden');
    clearAlert();
});

document.getElementById('back-to-login').addEventListener('click', (e) => {
    e.preventDefault();
    resetForm.classList.add('hidden');
    loginForm.classList.remove('hidden');
    clearAlert();
});

// Alert functions
function showAlert(message, type = 'error') {
    alertContainer.innerHTML = `<div class="alert alert-${type}">${message}</div>`;
}

function clearAlert() {
    alertContainer.innerHTML = '';
}

// Loading state
function setLoading(button, loading) {
    if (loading) {
        button.disabled = true;
        const originalText = button.textContent;
        button.dataset.originalText = originalText;
        button.innerHTML = originalText + '<span class="loading"></span>';
    } else {
        button.disabled = false;
        button.textContent = button.dataset.originalText || button.textContent;
    }
}

// Login
loginForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    clearAlert();

    const email = document.getElementById('login-email').value;
    const password = document.getElementById('login-password').value;
    const button = document.getElementById('login-btn');

    setLoading(button, true);

    try {
        const { data, error } = await authClient.auth.signInWithPassword({
            email,
            password
        });

        if (error) throw error;

        // Check if user has profile
        const { data: profile, error: profileError } = await authClient
            .from('user_profiles')
            .select('role, full_name, is_active')
            .eq('id', data.user.id)
            .single();

        if (profileError || !profile) {
            throw new Error('User profile not found. Please contact an administrator.');
        }

        if (!profile.is_active) {
            await authClient.auth.signOut();
            throw new Error('Your account has been deactivated. Please contact an administrator.');
        }

        // Update last login
        await authClient
            .from('user_profiles')
            .update({ last_login: new Date().toISOString() })
            .eq('id', data.user.id);

        // Log audit
        await logAudit(data.user.id, 'login', null, null, true);

        // Redirect to dashboard
        window.location.href = '/dashboard.html';
    } catch (error) {
        console.error('Login error:', error);
        showAlert(error.message || 'Login failed. Please try again.');
        setLoading(button, false);
    }
});

// Register
registerForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    clearAlert();

    const name = document.getElementById('register-name').value;
    const email = document.getElementById('register-email').value;
    const password = document.getElementById('register-password').value;
    const passwordConfirm = document.getElementById('register-password-confirm').value;
    const button = document.getElementById('register-btn');

    // Validate passwords match
    if (password !== passwordConfirm) {
        showAlert('Passwords do not match');
        return;
    }

    // Validate password strength
    if (password.length < 8) {
        showAlert('Password must be at least 8 characters long');
        return;
    }

    setLoading(button, true);

    try {
        // Sign up user
        const { data, error } = await authClient.auth.signUp({
            email,
            password,
            options: {
                data: {
                    full_name: name
                }
            }
        });

        if (error) throw error;

        if (data.user) {
            // Profile is created automatically by database trigger
            // Log audit (may fail if not confirmed yet, that's ok)
            try {
                await logAudit(data.user.id, 'register', null, null, true);
            } catch (auditError) {
                console.log('Audit log skipped (not confirmed yet)');
            }

            // Clear the form
            document.getElementById('register-name').value = '';
            document.getElementById('register-email').value = '';
            document.getElementById('register-password').value = '';
            document.getElementById('register-password-confirm').value = '';

            // Show success message with login link
            showAlert(
                '✅ Account created! Please check your email to confirm your account, then <a href="#" id="go-to-login" style="color: #667eea; text-decoration: underline; font-weight: bold;">login here</a>.',
                'success'
            );

            // Add click handler for the login link
            setTimeout(() => {
                const loginLink = document.getElementById('go-to-login');
                if (loginLink) {
                    loginLink.addEventListener('click', (e) => {
                        e.preventDefault();
                        switchTab('login');
                        document.getElementById('login-email').value = email;
                        document.getElementById('login-email').focus();
                    });
                }
            }, 100);
        }
    } catch (error) {
        console.error('Registration error:', error);
        showAlert(error.message || 'Registration failed. Please try again.');
    } finally {
        setLoading(button, false);
    }
});

// Password Reset
resetForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    clearAlert();

    const email = document.getElementById('reset-email').value;
    const button = document.getElementById('reset-btn');

    setLoading(button, true);

    try {
        const { error } = await authClient.auth.resetPasswordForEmail(email, {
            redirectTo: `${window.location.origin}/reset-password.html`
        });

        if (error) throw error;

        showAlert('Password reset link sent! Check your email.', 'success');

        // Clear form and go back to login after 3 seconds
        setTimeout(() => {
            document.getElementById('reset-email').value = '';
            resetForm.classList.add('hidden');
            loginForm.classList.remove('hidden');
        }, 3000);
    } catch (error) {
        console.error('Password reset error:', error);
        showAlert(error.message || 'Failed to send reset email. Please try again.');
    } finally {
        setLoading(button, false);
    }
});

// Audit logging helper
async function logAudit(userId, action, resourceType, resourceId, success, errorMessage = null) {
    try {
        await authClient.from('audit_log').insert({
            user_id: userId,
            action: action,
            resource_type: resourceType,
            resource_id: resourceId,
            ip_address: null, // Could add IP detection
            user_agent: navigator.userAgent,
            success: success,
            error_message: errorMessage
        });
    } catch (error) {
        console.error('Audit log error:', error);
        // Don't throw - audit failures shouldn't block auth
    }
}

// Check if user is already logged in
(async () => {
    try {
        if (!authClient) {
            console.log('ℹ️ Auth client not initialized, skipping session check');
            return;
        }

        console.log('🔍 Checking for existing session...');
        const { data: { session } } = await authClient.auth.getSession();

        if (session) {
            console.log('✅ Session found, showing already logged in message');
            // Get user profile to show their name
            let userName = 'User';
            try {
                const { data: profile } = await authClient
                    .from('user_profiles')
                    .select('full_name')
                    .eq('id', session.user.id)
                    .single();
                if (profile) userName = profile.full_name;
            } catch (e) {
                console.error('Error fetching profile:', e);
            }

            // Hide forms
            loginForm.classList.add('hidden');
            registerForm.classList.add('hidden');
            resetForm.classList.add('hidden');

            // Show already logged in message with options
            alertContainer.innerHTML = `
                <div class="alert alert-success" style="text-align: center; padding: 24px;">
                    <h3 style="margin-bottom: 16px; font-size: 18px;">✅ Already Logged In</h3>
                    <p style="margin-bottom: 20px;">You're logged in as <strong>${userName}</strong></p>
                    <div style="display: flex; gap: 12px; justify-content: center; flex-wrap: wrap;">
                        <button onclick="window.location.href='/dashboard.html'" class="btn" style="flex: 1; min-width: 150px;">
                            Go to Dashboard
                        </button>
                        <button onclick="handleLogoutFromLogin()" class="btn" style="flex: 1; min-width: 150px; background: #dc2626;">
                            Logout
                        </button>
                    </div>
                </div>
            `;
        } else {
            console.log('ℹ️ No session found, showing login form');
        }
    } catch (error) {
        console.error('❌ Error checking session:', error);
        // Don't show error to user, just let them see the login form
    }
})();

// Handle logout from login page
window.handleLogoutFromLogin = async function() {
    try {
        await authClient.auth.signOut();
        localStorage.clear();
        sessionStorage.clear();
        window.location.reload();
    } catch (error) {
        console.error('Logout error:', error);
        alert('Error logging out. Please clear your browser cookies.');
    }
};
