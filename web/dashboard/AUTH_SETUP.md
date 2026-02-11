## moveOmeter Authentication Setup Guide

Complete guide to setting up the authentication system with roles, MFA, and passkeys.

## Step 1: Run Database Migration

1. Go to Supabase Dashboard → SQL Editor
2. Open and run: `/database/setup_authentication.sql`
3. Verify tables created:
   - user_profiles
   - device_access
   - caretakee_devices
   - audit_log

## Step 2: Enable Auth Features in Supabase

### Email Authentication
1. Go to Authentication → Providers
2. Enable "Email" provider
3. **For testing:** Disable "Confirm email"
4. **For production:** Enable "Confirm email" and configure email templates

### Multi-Factor Authentication (TOTP)
1. Go to Authentication → Settings
2. Enable "Multi-Factor Authentication"
3. Set "MFA enforcement" to "Optional" (or "Required" for all users)

### WebAuthn (Passkeys)
1. Go to Authentication → Settings
2. Enable "WebAuthn/Passkeys"
3. Add your domain to allowed origins

## Step 3: Create First Admin User

### Option A: Through UI
1. Open `login.html` in browser
2. Click "Sign Up"
3. Create account (will default to 'caretaker' role)
4. Go to Supabase Dashboard → Table Editor → user_profiles
5. Find your user, change `role` to 'admin'

### Option B: Through SQL
```sql
-- First, sign up through the UI to create auth.users entry
-- Then run this (replace with your actual user ID):
UPDATE user_profiles
SET role = 'admin'
WHERE email = 'your-email@example.com';
```

## Step 4: Update Dashboard HTML

Add authentication guard to `index.html` (add after config.js):

```html
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
<script src="config.js"></script>
<script src="auth-guard.js"></script>
<!-- Rest of your scripts -->
```

Add user info and logout button to your dashboard header:

```html
<div class="user-info">
    <span id="user-name"></span>
    <span id="user-role"></span>
    <button id="logout-btn" class="btn">Logout</button>
</div>
```

## Step 5: Deploy Files

Upload new files to your server:
```bash
cd deployment
./deploy.sh deploy@167.71.107.200
```

Or manually:
```bash
scp login.html auth.js auth-guard.js deploy@167.71.107.200:/var/www/moveometer/
```

## User Roles & Permissions

### Admin (admin)
- ✅ Full system access
- ✅ User management
- ✅ View all devices and data
- ✅ Modify settings
- ✅ View audit logs

### Employee (employee)
- ✅ View all devices and data
- ✅ Add annotations
- ✅ Modify device settings
- ❌ User management
- ❌ System administration

### Caretaker (caretaker)
- ✅ View assigned devices only
- ✅ Add annotations to assigned devices
- ✅ View resident data for assigned devices
- ❌ Modify settings
- ❌ User management

### Caretakee (caretakee)
- ✅ View their own device(s) only
- ✅ View their own data
- ✅ Read-only access
- ❌ Cannot modify anything
- ❌ Cannot see other residents

## Assigning Device Access

### For Caretakers
As an admin, assign devices to caretakers:

```sql
-- Give caretaker access to a specific device
INSERT INTO device_access (user_id, device_id, access_level)
VALUES (
    'caretaker-user-uuid',
    'ESP32C6_001',
    'view'
);
```

### For Caretakees
Link a caretakee to their device:

```sql
-- Link caretakee to their own device
INSERT INTO caretakee_devices (caretakee_id, device_id, relationship, primary_device)
VALUES (
    'caretakee-user-uuid',
    'ESP32C6_001',
    'self',
    true
);
```

## Testing Authentication

1. **Test Login:**
   - Go to `http://your-server/login.html`
   - Sign in with your admin account
   - Should redirect to dashboard

2. **Test Role-Based Access:**
   - Create test users with different roles
   - Verify they only see appropriate devices/data

3. **Test Logout:**
   - Click logout button
   - Should redirect to login page
   - Cannot access dashboard without login

## Security Checklist

- [ ] Email confirmations enabled (production)
- [ ] Strong password requirements configured
- [ ] SSL/HTTPS enabled on server
- [ ] Supabase RLS policies tested
- [ ] Admin accounts secured with MFA
- [ ] Audit logging working
- [ ] Session timeout configured
- [ ] Password reset flow tested

## Next Steps

After basic auth is working:

1. **Add MFA/TOTP support** (Task #5)
   - QR code generation for authenticator apps
   - 6-digit code verification

2. **Add Passkey support** (Task #6)
   - WebAuthn registration
   - Biometric authentication

3. **Build Admin Panel** (Task #4)
   - User management UI
   - Device assignment interface
   - Role management

4. **Implement Role-Based Filtering** (Task #3)
   - Filter devices by user access
   - Show only authorized data

## Troubleshooting

**"User profile not found"**
- User signed up but profile wasn't created
- Run: `INSERT INTO user_profiles ...` manually

**"Permission denied" errors**
- RLS policies blocking access
- Check user role and device_access table
- Verify auth.uid() matches user ID

**Can't access dashboard after login**
- Check browser console for errors
- Verify auth-guard.js is loaded
- Check Supabase session is valid

**Dashboard shows all devices (should be filtered)**
- RLS policies not applied yet
- See Task #3 for role-based filtering implementation

## Support

For issues:
1. Check browser console for errors
2. Check Supabase logs (Dashboard → Logs)
3. Review audit_log table for failed attempts
4. Verify RLS policies in Database → Policies
