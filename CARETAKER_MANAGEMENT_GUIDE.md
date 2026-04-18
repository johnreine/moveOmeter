# Caretaker Management System

Complete system for Main Caretakers to invite and manage Additional Caretakers for their houses.

## Overview

**Roles:**
- **Main Caretaker**: Primary caretaker who owns/manages a house. Can add/remove additional caretakers.
- **Additional Caretaker**: Secondary caretaker invited by Main Caretaker. Has access to view and manage the house but cannot add/remove other caretakers.

**Features:**
- ✅ Main Caretaker can invite new caretakers by email
- ✅ Invitation email sent with signup/login link
- ✅ New users create account and accept invitation
- ✅ Existing users are added immediately
- ✅ Main Caretaker can view list of all caretakers
- ✅ Main Caretaker can remove additional caretakers
- ✅ Invitations expire after 7 days
- ✅ Main Caretaker can revoke pending invitations

## Database Setup

### 1. Run Migration

```bash
/database/create_caretaker_management.sql
```

This creates:
- `main_caretaker_id` column in `houses` table
- `house_caretakers` junction table
- `caretaker_invitations` table for pending invitations
- Functions for invite/remove/accept operations
- RLS policies for security

### 2. Set Main Caretakers

For existing houses, assign main caretakers:

```sql
-- Set main caretaker for a house
UPDATE houses
SET main_caretaker_id = '[user-id]'
WHERE id = '[house-id]';

-- Also add to house_caretakers table
INSERT INTO house_caretakers (house_id, caretaker_id, role, invitation_accepted, accepted_at)
VALUES ('[house-id]', '[user-id]', 'main_caretaker', TRUE, NOW())
ON CONFLICT (house_id, caretaker_id) DO NOTHING;
```

## Web Dashboard Implementation

### 3. Add HTML Elements

Add to `web/dashboard/index.html`:

**In header (after Android APP Alpha button):**
```html
<button id="add-caretaker-btn" class="btn-add-caretaker"
        onclick="openAddCaretakerModal()"
        style="display: none;">
    👥 Add Caretaker
</button>
```

**Before closing `</body>`:**
```html
<!-- Add Caretaker Modal -->
<div id="addCaretakerModal" class="modal">
    <div class="modal-content">
        <span class="close" onclick="closeAddCaretakerModal()">&times;</span>
        <h2>Add Caretaker</h2>
        <p>Invite someone to help care for this house</p>

        <form id="addCaretakerForm" onsubmit="submitCaretakerInvitation(event)">
            <div class="form-group">
                <label for="caretaker-email">Email Address</label>
                <input type="email"
                       id="caretaker-email"
                       name="email"
                       required
                       placeholder="caretaker@example.com"
                       autocomplete="email">
            </div>

            <div class="form-actions">
                <button type="button" onclick="closeAddCaretakerModal()">Cancel</button>
                <button type="submit" class="btn-primary">Send Invitation</button>
            </div>
        </form>
    </div>
</div>

<!-- Caretaker List (in settings or dedicated page) -->
<div id="caretaker-list"></div>

<!-- Include caretaker management script -->
<script src="caretaker_management.js"></script>
```

### 4. Add CSS Styles

Add to `web/dashboard/index.html` `<style>` section:

```css
.btn-add-caretaker {
    background: #10b981;
    color: white;
    padding: 8px 16px;
    border: none;
    border-radius: 5px;
    cursor: pointer;
    font-size: 14px;
    font-weight: 500;
    transition: all 0.3s;
}

.btn-add-caretaker:hover {
    background: #059669;
    transform: translateY(-1px);
}

.caretaker-section {
    background: white;
    padding: 20px;
    border-radius: 10px;
    margin-top: 20px;
}

.caretaker-list,
.invitation-list {
    list-style: none;
    padding: 0;
}

.caretaker-list li,
.invitation-list li {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 15px;
    border-bottom: 1px solid #eee;
}

.caretaker-info,
.invitation-info {
    flex: 1;
}

.caretaker-email,
.caretaker-meta,
.invitation-meta {
    font-size: 12px;
    color: #666;
    margin-top: 4px;
}

.main-badge {
    background: #667eea;
    color: white;
    padding: 2px 8px;
    border-radius: 12px;
    font-size: 11px;
    margin-left: 8px;
}

.btn-remove,
.btn-remove-small {
    background: #ef4444;
    color: white;
    border: none;
    padding: 6px 12px;
    border-radius: 4px;
    cursor: pointer;
    font-size: 12px;
}

.btn-remove-small {
    padding: 4px 8px;
    font-size: 11px;
}

.btn-remove:hover,
.btn-remove-small:hover {
    background: #dc2626;
}

.no-data {
    text-align: center;
    color: #999;
    padding: 20px;
}
```

## Email System Setup

### 5. Create Supabase Edge Function for Email Sending

Create `supabase/functions/send-email/index.ts`:

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

serve(async (req) => {
  try {
    const { to, subject, text } = await req.json()

    // Use your email service (SendGrid, Mailgun, Resend, etc.)
    // Example with Resend:
    const response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${Deno.env.get('RESEND_API_KEY')}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: 'moveOmeter <noreply@moveometer.com>',
        to,
        subject,
        text,
      }),
    })

    const data = await response.json()

    return new Response(JSON.stringify({ success: true, data }), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})
```

**Deploy:**
```bash
supabase functions deploy send-email --no-verify-jwt
```

### 6. Create Accept Invitation Page

Create `web/accept-invitation.html`:

```html
<!DOCTYPE html>
<html>
<head>
    <title>Accept Invitation - moveOmeter</title>
    <!-- Include your styles -->
</head>
<body>
    <div class="container">
        <h1>Accept Caretaker Invitation</h1>
        <div id="status-message"></div>

        <form id="acceptForm" onsubmit="acceptInvitation(event)">
            <input type="password" id="password" placeholder="Create Password" required>
            <input type="password" id="confirm-password" placeholder="Confirm Password" required>
            <button type="submit">Accept & Create Account</button>
        </form>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
    <script src="config.js"></script>
    <script>
        const supabase = getSupabaseClient();
        const urlParams = new URLSearchParams(window.location.search);
        const token = urlParams.get('token');

        if (!token) {
            document.getElementById('status-message').innerHTML =
                '<p class="error">Invalid invitation link</p>';
            document.getElementById('acceptForm').style.display = 'none';
        }

        async function acceptInvitation(event) {
            event.preventDefault();

            const password = document.getElementById('password').value;
            const confirmPassword = document.getElementById('confirm-password').value;

            if (password !== confirmPassword) {
                alert('Passwords do not match');
                return;
            }

            if (password.length < 8) {
                alert('Password must be at least 8 characters');
                return;
            }

            try {
                // Get invitation details
                const { data: invitation, error: invError } = await supabase
                    .from('caretaker_invitations')
                    .select('email, house_id')
                    .eq('invitation_token', token)
                    .eq('status', 'pending')
                    .single();

                if (invError) throw new Error('Invalid or expired invitation');

                // Create user account
                const { data: authData, error: authError } = await supabase.auth.signUp({
                    email: invitation.email,
                    password: password,
                });

                if (authError) throw authError;

                // Accept invitation
                const { error: acceptError } = await supabase.rpc('accept_invitation', {
                    p_token: token,
                    p_user_id: authData.user.id
                });

                if (acceptError) throw acceptError;

                alert('✅ Account created! Redirecting to dashboard...');
                window.location.href = 'dashboard.html';

            } catch (err) {
                alert(`❌ Error: ${err.message}`);
            }
        }
    </script>
</body>
</html>
```

## Mobile App Implementation

### 7. Add to Flutter App

**Create `lib/pages/manage_caretakers_page.dart`:**

```dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/analytics_service.dart';

class ManageCaretakersPage extends StatefulWidget {
  final String houseId;
  final String houseName;

  const ManageCaretakersPage({
    super.key,
    required this.houseId,
    required this.houseName,
  });

  @override
  State<ManageCaretakersPage> createState() => _ManageCaretakersPageState();
}

class _ManageCaretakersPageState extends State<ManageCaretakersPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _caretakers = [];
  List<Map<String, dynamic>> _invitations = [];
  bool _isLoading = true;
  bool _isMainCaretaker = false;

  @override
  void initState() {
    super.initState();
    analyticsService.trackScreenView('ManageCaretakersPage');
    _checkMainCaretaker();
    _loadCaretakers();
  }

  Future<void> _checkMainCaretaker() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final response = await _supabase
          .from('houses')
          .select('main_caretaker_id')
          .eq('id', widget.houseId)
          .single();

      setState(() {
        _isMainCaretaker = response['main_caretaker_id'] == userId;
      });
    } catch (e) {
      print('Error checking main caretaker: $e');
    }
  }

  Future<void> _loadCaretakers() async {
    setState(() => _isLoading = true);

    try {
      // Get caretakers
      final caretakers = await _supabase.rpc('get_house_caretakers',
          params: {'p_house_id': widget.houseId});

      // Get pending invitations
      final invitations = await _supabase.rpc('get_pending_invitations',
          params: {'p_house_id': widget.houseId});

      setState(() {
        _caretakers = List<Map<String, dynamic>>.from(caretakers ?? []);
        _invitations = List<Map<String, dynamic>>.from(invitations ?? []);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading caretakers: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showAddCaretakerDialog() async {
    final emailController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Caretaker'),
        content: TextField(
          controller: emailController,
          decoration: const InputDecoration(
            labelText: 'Email Address',
            hintText: 'caretaker@example.com',
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send Invitation'),
          ),
        ],
      ),
    );

    if (result == true && emailController.text.isNotEmpty) {
      await _inviteCaretaker(emailController.text.trim());
    }
  }

  Future<void> _inviteCaretaker(String email) async {
    try {
      await _supabase.rpc('invite_caretaker', params: {
        'p_house_id': widget.houseId,
        'p_email': email,
        'p_invited_by': _supabase.auth.currentUser!.id,
      });

      analyticsService.trackAction('caretaker_invited', 'caretaker_management',
          'invite', actionValue: email);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Invitation sent to $email')),
        );
        _loadCaretakers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _removeCaretaker(String caretakerId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Caretaker'),
        content: Text('Remove $name as a caretaker?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _supabase.rpc('remove_caretaker', params: {
          'p_house_id': widget.houseId,
          'p_caretaker_id': caretakerId,
          'p_removed_by': _supabase.auth.currentUser!.id,
        });

        analyticsService.trackAction('caretaker_removed',
            'caretaker_management', 'remove', actionValue: caretakerId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Caretaker removed')),
          );
          _loadCaretakers();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ Error: ${e.toString()}')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Caretakers'),
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        actions: [
          if (_isMainCaretaker)
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: _showAddCaretakerDialog,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCaretakers,
              child: ListView(
                children: [
                  // Caretakers
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Caretakers',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ..._caretakers.map((c) => ListTile(
                        leading: CircleAvatar(
                          child: Text(c['full_name'][0].toUpperCase()),
                        ),
                        title: Row(
                          children: [
                            Text(c['full_name']),
                            if (c['is_main_caretaker'])
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF667eea),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Main',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 11),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text(c['email']),
                        trailing: !c['is_main_caretaker'] && _isMainCaretaker
                            ? IconButton(
                                icon: const Icon(Icons.remove_circle,
                                    color: Colors.red),
                                onPressed: () => _removeCaretaker(
                                    c['caretaker_id'], c['full_name']),
                              )
                            : null,
                      )),

                  // Pending Invitations
                  if (_invitations.isNotEmpty) ...[
                    const Divider(),
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Pending Invitations',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    ..._invitations.map((inv) => ListTile(
                          leading: const Icon(Icons.mail_outline),
                          title: Text(inv['email']),
                          subtitle: Text('Invited by ${inv['invited_by_name']}'),
                        )),
                  ],
                ],
              ),
            ),
    );
  }
}
```

## Testing

### 8. Test the System

**As Main Caretaker:**
1. Login to dashboard
2. Click "Add Caretaker" button
3. Enter email address
4. Submit invitation
5. Check email was sent
6. View caretaker list
7. Remove a caretaker

**As New Caretaker:**
1. Receive invitation email
2. Click invitation link
3. Create account with password
4. Login to dashboard
5. See house in house list

**As Existing Caretaker:**
1. Receive notification (or see immediately)
2. Login to dashboard
3. See house in house list

## Next Steps

1. ✅ Run database migration
2. ✅ Set main caretakers for existing houses
3. ✅ Add HTML/JS to dashboard
4. ✅ Create email sending edge function
5. ✅ Create accept invitation page
6. ✅ Add to mobile app
7. ✅ Test complete flow
8. ⬜ Create admin view to see all caretaker relationships
9. ⬜ Add notifications for new invitations
10. ⬜ Add ability to transfer Main Caretaker role

## Security Notes

- Only Main Caretakers can add/remove caretakers
- RLS policies enforce access control
- Invitation tokens are cryptographically secure
- Invitations expire after 7 days
- Removed caretakers lose access immediately
- Main Caretaker cannot remove themselves
