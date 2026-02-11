// Authentication Guard for Dashboard
// Include this at the top of dashboard pages to protect them

(async () => {
    const { createClient } = window.supabase;
    const authClient = createClient(SUPABASE_CONFIG.url, SUPABASE_CONFIG.anonKey);

    // Check if user is authenticated
    const { data: { session }, error } = await authClient.auth.getSession();

    if (error || !session) {
        // Not authenticated, redirect to login
        window.location.href = 'login.html';
        return;
    }

    // User is authenticated, fetch their profile
    const { data: profile, error: profileError } = await authClient
        .from('user_profiles')
        .select('*')
        .eq('id', session.user.id)
        .single();

    if (profileError || !profile) {
        console.error('Profile fetch error:', profileError);
        alert('Profile not found. Please contact an administrator.');
        await authClient.auth.signOut();
        window.location.href = 'login.html';
        return;
    }

    if (!profile.is_active) {
        alert('Your account has been deactivated. Please contact an administrator.');
        await authClient.auth.signOut();
        window.location.href = 'login.html';
        return;
    }

    // Store user profile in window for access throughout the app
    window.currentUser = {
        id: session.user.id,
        email: profile.email,
        role: profile.role,
        full_name: profile.full_name,
        fullName: profile.full_name,
        profile: profile,
        session: session
    };

    console.log('✅ Authenticated user:', window.currentUser.fullName, `(${window.currentUser.role})`);

    // Set up auth state change listener
    authClient.auth.onAuthStateChange((event, session) => {
        if (event === 'SIGNED_OUT') {
            window.location.href = 'login.html';
        } else if (event === 'TOKEN_REFRESHED') {
            console.log('🔄 Session token refreshed');
        } else if (event === 'USER_UPDATED') {
            console.log('👤 User profile updated');
        }
    });

    // Add logout button handler if it exists
    const logoutBtn = document.getElementById('logout-btn');
    if (logoutBtn) {
        logoutBtn.addEventListener('click', async () => {
            if (confirm('Are you sure you want to sign out?')) {
                await authClient.auth.signOut();
                window.location.href = 'login.html';
            }
        });
    }

    // Update UI with user info
    const userNameElement = document.getElementById('user-name');
    if (userNameElement) {
        userNameElement.textContent = window.currentUser.fullName;
    }

    const userRoleElement = document.getElementById('user-role');
    if (userRoleElement) {
        const roleLabels = {
            'admin': '👑 Admin',
            'employee': '👔 Employee',
            'caretaker': '🤝 Caretaker',
            'caretakee': '👤 Resident'
        };
        userRoleElement.textContent = roleLabels[window.currentUser.role] || window.currentUser.role;
    }

    // Show/hide admin features based on role
    const adminElements = document.querySelectorAll('.admin-only');
    adminElements.forEach(el => {
        if (window.currentUser.role === 'admin') {
            el.style.display = 'block';
        } else {
            el.style.display = 'none';
        }
    });

    const employeeElements = document.querySelectorAll('.employee-only');
    employeeElements.forEach(el => {
        if (['admin', 'employee'].includes(window.currentUser.role)) {
            el.style.display = 'inline-block';
        } else {
            el.style.display = 'none';
        }
    });
})();
