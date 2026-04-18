-- ============================================
-- Caretaker Management System
-- ============================================
-- Allows Main Caretakers to add/remove Additional Caretakers to houses

-- Add main_caretaker_id to houses table
ALTER TABLE houses
ADD COLUMN IF NOT EXISTS main_caretaker_id UUID REFERENCES auth.users(id) ON DELETE SET NULL;

COMMENT ON COLUMN houses.main_caretaker_id IS 'Primary caretaker who can manage additional caretakers';

-- Create house_caretakers junction table
CREATE TABLE IF NOT EXISTS house_caretakers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  house_id UUID NOT NULL REFERENCES houses(id) ON DELETE CASCADE,
  caretaker_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Invitation tracking
  invited_by UUID REFERENCES auth.users(id),
  invited_at TIMESTAMPTZ DEFAULT NOW(),
  invitation_accepted BOOLEAN DEFAULT FALSE,
  accepted_at TIMESTAMPTZ,

  -- Access level
  role TEXT DEFAULT 'caretaker', -- 'caretaker' or 'main_caretaker'

  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- Ensure one entry per house-caretaker pair
  UNIQUE(house_id, caretaker_id)
);

CREATE INDEX idx_house_caretakers_house ON house_caretakers(house_id);
CREATE INDEX idx_house_caretakers_user ON house_caretakers(caretaker_id);
CREATE INDEX idx_house_caretakers_invited_by ON house_caretakers(invited_by);

COMMENT ON TABLE house_caretakers IS 'Links caretakers to houses they have access to';
COMMENT ON COLUMN house_caretakers.role IS 'Access level: main_caretaker or caretaker';

-- Create caretaker_invitations table for pending invitations
CREATE TABLE IF NOT EXISTS caretaker_invitations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  house_id UUID NOT NULL REFERENCES houses(id) ON DELETE CASCADE,
  email TEXT NOT NULL,

  -- Invitation details
  invited_by UUID NOT NULL REFERENCES auth.users(id),
  invited_at TIMESTAMPTZ DEFAULT NOW(),
  invitation_token TEXT UNIQUE,

  -- Status
  status TEXT DEFAULT 'pending', -- 'pending', 'accepted', 'expired', 'revoked'
  accepted_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '7 days'),

  -- User created from invitation
  created_user_id UUID REFERENCES auth.users(id),

  created_at TIMESTAMPTZ DEFAULT NOW(),

  -- One pending invitation per email per house
  UNIQUE(house_id, email, status)
);

CREATE INDEX idx_caretaker_invitations_house ON caretaker_invitations(house_id);
CREATE INDEX idx_caretaker_invitations_email ON caretaker_invitations(email);
CREATE INDEX idx_caretaker_invitations_token ON caretaker_invitations(invitation_token);
CREATE INDEX idx_caretaker_invitations_status ON caretaker_invitations(status);

COMMENT ON TABLE caretaker_invitations IS 'Tracks pending and completed caretaker invitations';

-- Function to get all caretakers for a house
CREATE OR REPLACE FUNCTION get_house_caretakers(p_house_id UUID)
RETURNS TABLE (
  caretaker_id UUID,
  email TEXT,
  full_name TEXT,
  role TEXT,
  is_main_caretaker BOOLEAN,
  invited_by_name TEXT,
  invited_at TIMESTAMPTZ,
  invitation_accepted BOOLEAN
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    u.id as caretaker_id,
    up.email,
    up.full_name,
    hc.role,
    (h.main_caretaker_id = u.id) as is_main_caretaker,
    inviter.full_name as invited_by_name,
    hc.invited_at,
    hc.invitation_accepted
  FROM house_caretakers hc
  JOIN auth.users u ON u.id = hc.caretaker_id
  JOIN user_profiles up ON up.id = u.id
  LEFT JOIN user_profiles inviter ON inviter.id = hc.invited_by
  LEFT JOIN houses h ON h.id = hc.house_id
  WHERE hc.house_id = p_house_id
  ORDER BY
    is_main_caretaker DESC,
    up.full_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get pending invitations for a house
CREATE OR REPLACE FUNCTION get_pending_invitations(p_house_id UUID)
RETURNS TABLE (
  invitation_id UUID,
  email TEXT,
  invited_by_name TEXT,
  invited_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  status TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    ci.id as invitation_id,
    ci.email,
    up.full_name as invited_by_name,
    ci.invited_at,
    ci.expires_at,
    ci.status
  FROM caretaker_invitations ci
  JOIN user_profiles up ON up.id = ci.invited_by
  WHERE ci.house_id = p_house_id
    AND ci.status = 'pending'
    AND ci.expires_at > NOW()
  ORDER BY ci.invited_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to invite a caretaker
CREATE OR REPLACE FUNCTION invite_caretaker(
  p_house_id UUID,
  p_email TEXT,
  p_invited_by UUID
)
RETURNS UUID AS $$
DECLARE
  v_invitation_id UUID;
  v_token TEXT;
  v_existing_user_id UUID;
BEGIN
  -- Validate that the inviter is the main caretaker
  IF NOT EXISTS (
    SELECT 1 FROM houses
    WHERE id = p_house_id AND main_caretaker_id = p_invited_by
  ) THEN
    RAISE EXCEPTION 'Only the main caretaker can invite additional caretakers';
  END IF;

  -- Check if user already exists
  SELECT id INTO v_existing_user_id
  FROM user_profiles
  WHERE email = p_email;

  -- If user exists, add them directly to house_caretakers
  IF v_existing_user_id IS NOT NULL THEN
    -- Check if already a caretaker
    IF EXISTS (
      SELECT 1 FROM house_caretakers
      WHERE house_id = p_house_id AND caretaker_id = v_existing_user_id
    ) THEN
      RAISE EXCEPTION 'User is already a caretaker for this house';
    END IF;

    -- Add to house_caretakers
    INSERT INTO house_caretakers (
      house_id,
      caretaker_id,
      invited_by,
      invitation_accepted,
      accepted_at,
      role
    ) VALUES (
      p_house_id,
      v_existing_user_id,
      p_invited_by,
      TRUE,
      NOW(),
      'caretaker'
    );

    RETURN NULL; -- No invitation needed
  END IF;

  -- Generate invitation token
  v_token := encode(gen_random_bytes(32), 'base64');

  -- Create invitation
  INSERT INTO caretaker_invitations (
    house_id,
    email,
    invited_by,
    invitation_token,
    status
  ) VALUES (
    p_house_id,
    p_email,
    p_invited_by,
    v_token,
    'pending'
  )
  RETURNING id INTO v_invitation_id;

  RETURN v_invitation_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to remove a caretaker
CREATE OR REPLACE FUNCTION remove_caretaker(
  p_house_id UUID,
  p_caretaker_id UUID,
  p_removed_by UUID
)
RETURNS BOOLEAN AS $$
BEGIN
  -- Validate that the remover is the main caretaker
  IF NOT EXISTS (
    SELECT 1 FROM houses
    WHERE id = p_house_id AND main_caretaker_id = p_removed_by
  ) THEN
    RAISE EXCEPTION 'Only the main caretaker can remove caretakers';
  END IF;

  -- Prevent removing the main caretaker
  IF p_caretaker_id = p_removed_by THEN
    RAISE EXCEPTION 'Cannot remove yourself as main caretaker';
  END IF;

  -- Remove from house_caretakers
  DELETE FROM house_caretakers
  WHERE house_id = p_house_id AND caretaker_id = p_caretaker_id;

  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to revoke a pending invitation
CREATE OR REPLACE FUNCTION revoke_invitation(
  p_invitation_id UUID,
  p_revoked_by UUID
)
RETURNS BOOLEAN AS $$
DECLARE
  v_house_id UUID;
BEGIN
  -- Get house_id from invitation
  SELECT house_id INTO v_house_id
  FROM caretaker_invitations
  WHERE id = p_invitation_id;

  -- Validate that the revoker is the main caretaker
  IF NOT EXISTS (
    SELECT 1 FROM houses
    WHERE id = v_house_id AND main_caretaker_id = p_revoked_by
  ) THEN
    RAISE EXCEPTION 'Only the main caretaker can revoke invitations';
  END IF;

  -- Update invitation status
  UPDATE caretaker_invitations
  SET status = 'revoked'
  WHERE id = p_invitation_id;

  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to accept an invitation
CREATE OR REPLACE FUNCTION accept_invitation(
  p_token TEXT,
  p_user_id UUID
)
RETURNS BOOLEAN AS $$
DECLARE
  v_invitation RECORD;
BEGIN
  -- Get invitation details
  SELECT * INTO v_invitation
  FROM caretaker_invitations
  WHERE invitation_token = p_token
    AND status = 'pending'
    AND expires_at > NOW();

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invalid or expired invitation';
  END IF;

  -- Verify email matches
  IF NOT EXISTS (
    SELECT 1 FROM user_profiles
    WHERE id = p_user_id AND email = v_invitation.email
  ) THEN
    RAISE EXCEPTION 'Email does not match invitation';
  END IF;

  -- Add to house_caretakers
  INSERT INTO house_caretakers (
    house_id,
    caretaker_id,
    invited_by,
    invitation_accepted,
    accepted_at,
    role
  ) VALUES (
    v_invitation.house_id,
    p_user_id,
    v_invitation.invited_by,
    TRUE,
    NOW(),
    'caretaker'
  );

  -- Update invitation
  UPDATE caretaker_invitations
  SET
    status = 'accepted',
    accepted_at = NOW(),
    created_user_id = p_user_id
  WHERE id = v_invitation.id;

  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Enable RLS
ALTER TABLE house_caretakers ENABLE ROW LEVEL SECURITY;
ALTER TABLE caretaker_invitations ENABLE ROW LEVEL SECURITY;

-- RLS Policies for house_caretakers
CREATE POLICY "Users can view caretakers for their houses"
  ON house_caretakers FOR SELECT
  USING (
    house_id IN (
      SELECT house_id FROM house_caretakers WHERE caretaker_id = auth.uid()
    )
  );

CREATE POLICY "Main caretakers can manage caretakers"
  ON house_caretakers FOR ALL
  USING (
    house_id IN (
      SELECT id FROM houses WHERE main_caretaker_id = auth.uid()
    )
  );

-- RLS Policies for caretaker_invitations
CREATE POLICY "Users can view invitations for their houses"
  ON caretaker_invitations FOR SELECT
  USING (
    house_id IN (
      SELECT house_id FROM house_caretakers WHERE caretaker_id = auth.uid()
    )
    OR email IN (
      SELECT email FROM user_profiles WHERE id = auth.uid()
    )
  );

CREATE POLICY "Main caretakers can manage invitations"
  ON caretaker_invitations FOR ALL
  USING (
    house_id IN (
      SELECT id FROM houses WHERE main_caretaker_id = auth.uid()
    )
  );

SELECT 'Caretaker management system created successfully!' AS status;
