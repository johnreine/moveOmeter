// Caretaker Management for moveOmeter Dashboard
// Allows Main Caretakers to add/remove additional caretakers

let currentHouseId = null;
let isMainCaretaker = false;

// Initialize caretaker management
async function initCaretakerManagement() {
    // Check if user has any houses
    const houses = await getUserHouses();

    if (houses.length > 0) {
        // Use first house (or let user select)
        currentHouseId = houses[0].id;

        // Check if user is main caretaker
        isMainCaretaker = houses[0].main_caretaker_id === window.currentUser.id;

        // Show/hide Add Caretaker button
        const addCaretakerBtn = document.getElementById('add-caretaker-btn');
        if (addCaretakerBtn) {
            addCaretakerBtn.style.display = isMainCaretaker ? 'inline-block' : 'none';
        }
    }
}

// Get user's houses
async function getUserHouses() {
    try {
        const { data, error } = await db
            .from('houses')
            .select('id, name, main_caretaker_id')
            .eq('is_active', true);

        if (error) throw error;
        return data || [];
    } catch (err) {
        console.error('Error fetching houses:', err);
        return [];
    }
}

// Open add caretaker modal
function openAddCaretakerModal() {
    if (!isMainCaretaker) {
        alert('Only the main caretaker can add additional caretakers');
        return;
    }

    trackAction('caretaker_modal_open', 'caretaker_management', 'add_caretaker');

    const modal = document.getElementById('addCaretakerModal');
    const form = document.getElementById('addCaretakerForm');
    form.reset();
    modal.style.display = 'block';
}

// Close add caretaker modal
function closeAddCaretakerModal() {
    const modal = document.getElementById('addCaretakerModal');
    modal.style.display = 'none';
}

// Submit caretaker invitation
async function submitCaretakerInvitation(event) {
    event.preventDefault();

    const email = document.getElementById('caretaker-email').value.trim().toLowerCase();
    const submitBtn = event.target.querySelector('button[type="submit"]');
    const originalText = submitBtn.textContent;

    // Validate email
    if (!email || !email.includes('@')) {
        alert('Please enter a valid email address');
        return;
    }

    submitBtn.disabled = true;
    submitBtn.textContent = 'Sending invitation...';

    try {
        // Call invite_caretaker function
        const { data, error } = await db.rpc('invite_caretaker', {
            p_house_id: currentHouseId,
            p_email: email,
            p_invited_by: window.currentUser.id
        });

        if (error) throw error;

        // Track invitation
        trackAction('caretaker_invited', 'caretaker_management', 'send_invitation', email);

        // Send invitation email
        await sendInvitationEmail(email, data);

        alert(`✅ Invitation sent to ${email}`);
        closeAddCaretakerModal();

        // Refresh caretaker list
        await loadCaretakerList();

    } catch (err) {
        console.error('Error inviting caretaker:', err);
        alert(`❌ Error: ${err.message}`);
    } finally {
        submitBtn.disabled = false;
        submitBtn.textContent = originalText;
    }
}

// Send invitation email
async function sendInvitationEmail(email, invitationId) {
    try {
        // Get house info
        const { data: house } = await db
            .from('houses')
            .select('name')
            .eq('id', currentHouseId)
            .single();

        const houseName = house?.name || 'a house';
        const inviterName = window.currentUser.fullName;

        // Get invitation token (if new user)
        let invitationToken = null;
        if (invitationId) {
            const { data: invitation } = await db
                .from('caretaker_invitations')
                .select('invitation_token')
                .eq('id', invitationId)
                .single();

            invitationToken = invitation?.invitation_token;
        }

        // Build invitation URL
        const baseUrl = window.location.origin;
        const invitationUrl = invitationToken
            ? `${baseUrl}/accept-invitation.html?token=${invitationToken}`
            : `${baseUrl}/login.html`;

        // Email template
        const emailSubject = `You've been invited to ${houseName} on moveOmeter`;
        const emailBody = `
Hi,

${inviterName} has invited you to be a caretaker for ${houseName} on moveOmeter.

${invitationToken ? 'Click the link below to create your account and accept the invitation:' : 'You already have an account. Log in to access the house:'}

${invitationUrl}

${invitationToken ? 'This invitation will expire in 7 days.' : ''}

Best regards,
The moveOmeter Team
        `.trim();

        // Use Supabase Edge Function to send email
        // (You'll need to create this edge function)
        const { error } = await db.functions.invoke('send-email', {
            body: {
                to: email,
                subject: emailSubject,
                text: emailBody
            }
        });

        if (error) {
            console.warn('Email sending failed (edge function may not exist):', error);
            // Show invitation URL to user as fallback
            console.log('Invitation URL:', invitationUrl);
        }

    } catch (err) {
        console.error('Error sending email:', err);
    }
}

// Load caretaker list
async function loadCaretakerList() {
    const container = document.getElementById('caretaker-list');
    if (!container) return;

    try {
        // Get caretakers
        const { data: caretakers, error } = await db.rpc('get_house_caretakers', {
            p_house_id: currentHouseId
        });

        if (error) throw error;

        // Get pending invitations
        const { data: invitations } = await db.rpc('get_pending_invitations', {
            p_house_id: currentHouseId
        });

        // Render list
        let html = '<div class="caretaker-section">';
        html += '<h3>Caretakers</h3>';

        if (caretakers && caretakers.length > 0) {
            html += '<ul class="caretaker-list">';
            caretakers.forEach(c => {
                const badge = c.is_main_caretaker ? '<span class="main-badge">Main</span>' : '';
                const removeBtn = !c.is_main_caretaker && isMainCaretaker
                    ? `<button onclick="removeCaretaker('${c.caretaker_id}')" class="btn-remove">Remove</button>`
                    : '';

                html += `
                    <li>
                        <div class="caretaker-info">
                            <strong>${c.full_name}</strong> ${badge}
                            <div class="caretaker-email">${c.email}</div>
                            ${c.invited_by_name && !c.is_main_caretaker ? `<div class="caretaker-meta">Invited by ${c.invited_by_name}</div>` : ''}
                        </div>
                        ${removeBtn}
                    </li>
                `;
            });
            html += '</ul>';
        } else {
            html += '<p class="no-data">No caretakers yet</p>';
        }

        // Pending invitations
        if (invitations && invitations.length > 0) {
            html += '<h4>Pending Invitations</h4>';
            html += '<ul class="invitation-list">';
            invitations.forEach(inv => {
                const revokeBtn = isMainCaretaker
                    ? `<button onclick="revokeInvitation('${inv.invitation_id}')" class="btn-remove-small">Revoke</button>`
                    : '';

                html += `
                    <li>
                        <div class="invitation-info">
                            <strong>${inv.email}</strong>
                            <div class="invitation-meta">
                                Invited by ${inv.invited_by_name} •
                                Expires ${new Date(inv.expires_at).toLocaleDateString()}
                            </div>
                        </div>
                        ${revokeBtn}
                    </li>
                `;
            });
            html += '</ul>';
        }

        html += '</div>';
        container.innerHTML = html;

    } catch (err) {
        console.error('Error loading caretakers:', err);
        container.innerHTML = `<p class="error">Error loading caretakers: ${err.message}</p>`;
    }
}

// Remove caretaker
async function removeCaretaker(caretakerId) {
    if (!confirm('Are you sure you want to remove this caretaker?')) {
        return;
    }

    try {
        const { error } = await db.rpc('remove_caretaker', {
            p_house_id: currentHouseId,
            p_caretaker_id: caretakerId,
            p_removed_by: window.currentUser.id
        });

        if (error) throw error;

        trackAction('caretaker_removed', 'caretaker_management', 'remove_caretaker');

        alert('✅ Caretaker removed');
        await loadCaretakerList();

    } catch (err) {
        console.error('Error removing caretaker:', err);
        alert(`❌ Error: ${err.message}`);
    }
}

// Revoke invitation
async function revokeInvitation(invitationId) {
    if (!confirm('Are you sure you want to revoke this invitation?')) {
        return;
    }

    try {
        const { error } = await db.rpc('revoke_invitation', {
            p_invitation_id: invitationId,
            p_revoked_by: window.currentUser.id
        });

        if (error) throw error;

        trackAction('invitation_revoked', 'caretaker_management', 'revoke_invitation');

        alert('✅ Invitation revoked');
        await loadCaretakerList();

    } catch (err) {
        console.error('Error revoking invitation:', err);
        alert(`❌ Error: ${err.message}`);
    }
}

// Initialize on page load
document.addEventListener('DOMContentLoaded', async () => {
    // Wait for auth to complete
    setTimeout(async () => {
        if (window.currentUser) {
            await initCaretakerManagement();
        }
    }, 1000);
});
