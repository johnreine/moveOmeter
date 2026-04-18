-- ============================================
-- Analytics Tables for Web and Mobile Apps
-- ============================================
-- Tracks user logins, sessions, actions, and app usage

-- User Sessions (Web Dashboard)
CREATE TABLE IF NOT EXISTS user_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  session_start TIMESTAMPTZ DEFAULT NOW(),
  session_end TIMESTAMPTZ,
  duration_seconds INTEGER,

  -- Session metadata
  ip_address TEXT,
  user_agent TEXT,
  browser TEXT,
  os TEXT,
  device_type TEXT, -- 'desktop', 'tablet', 'mobile'
  screen_resolution TEXT,

  -- Activity metrics
  page_views INTEGER DEFAULT 0,
  actions_count INTEGER DEFAULT 0,

  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_user_sessions_user_id ON user_sessions(user_id);
CREATE INDEX idx_user_sessions_start ON user_sessions(session_start DESC);

-- User Actions (Web Dashboard)
CREATE TABLE IF NOT EXISTS user_actions (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  session_id UUID REFERENCES user_sessions(id) ON DELETE CASCADE,

  -- Action details
  action_type TEXT NOT NULL, -- 'page_view', 'button_click', 'chart_interaction', 'device_view', etc.
  action_category TEXT, -- 'navigation', 'device_management', 'data_view', 'settings', etc.
  action_target TEXT, -- specific element clicked or page viewed
  action_value TEXT, -- additional context (JSON or text)

  -- Context
  page_url TEXT,
  referrer TEXT,

  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_user_actions_user_id ON user_actions(user_id);
CREATE INDEX idx_user_actions_session_id ON user_actions(session_id);
CREATE INDEX idx_user_actions_type ON user_actions(action_type);
CREATE INDEX idx_user_actions_created ON user_actions(created_at DESC);

-- User Login Stats (Aggregated)
CREATE TABLE IF NOT EXISTS user_login_stats (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Login metrics
  total_logins INTEGER DEFAULT 0,
  first_login_at TIMESTAMPTZ,
  last_login_at TIMESTAMPTZ,

  -- Session metrics
  total_sessions INTEGER DEFAULT 0,
  total_session_duration_seconds BIGINT DEFAULT 0,
  average_session_duration_seconds INTEGER,
  longest_session_duration_seconds INTEGER DEFAULT 0,

  -- Activity metrics
  total_page_views INTEGER DEFAULT 0,
  total_actions INTEGER DEFAULT 0,

  -- Most used features (JSON)
  top_actions JSONB,

  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- App Sessions (Mobile Apps - iOS & Android)
CREATE TABLE IF NOT EXISTS app_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,

  -- App info
  app_platform TEXT NOT NULL, -- 'ios' or 'android'
  app_version TEXT NOT NULL, -- '1.0.0+1'
  build_number TEXT,

  -- Session timing
  session_start TIMESTAMPTZ DEFAULT NOW(),
  session_end TIMESTAMPTZ,
  duration_seconds INTEGER,

  -- Device info
  device_model TEXT,
  device_os_version TEXT,
  device_id TEXT, -- Anonymous device identifier

  -- Activity metrics
  screens_viewed INTEGER DEFAULT 0,
  actions_count INTEGER DEFAULT 0,

  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_app_sessions_user_id ON app_sessions(user_id);
CREATE INDEX idx_app_sessions_platform ON app_sessions(app_platform);
CREATE INDEX idx_app_sessions_version ON app_sessions(app_version);
CREATE INDEX idx_app_sessions_start ON app_sessions(session_start DESC);

-- App Actions (Mobile Apps)
CREATE TABLE IF NOT EXISTS app_actions (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  session_id UUID REFERENCES app_sessions(id) ON DELETE CASCADE,

  -- Action details
  action_type TEXT NOT NULL, -- 'screen_view', 'button_tap', 'device_action', etc.
  action_category TEXT, -- 'navigation', 'device_management', 'data_view', 'settings', etc.
  action_target TEXT, -- specific screen or button
  action_value TEXT, -- additional context

  -- Context
  screen_name TEXT,

  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_app_actions_user_id ON app_actions(user_id);
CREATE INDEX idx_app_actions_session_id ON app_actions(session_id);
CREATE INDEX idx_app_actions_type ON app_actions(action_type);
CREATE INDEX idx_app_actions_created ON app_actions(created_at DESC);

-- App Usage Stats (Aggregated)
CREATE TABLE IF NOT EXISTS app_usage_stats (
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  app_platform TEXT NOT NULL, -- 'ios' or 'android'

  -- Version tracking
  current_version TEXT,
  last_version_update TIMESTAMPTZ,

  -- Usage metrics
  total_sessions INTEGER DEFAULT 0,
  total_session_duration_seconds BIGINT DEFAULT 0,
  average_session_duration_seconds INTEGER,
  first_used_at TIMESTAMPTZ,
  last_used_at TIMESTAMPTZ,

  -- Activity metrics
  total_screens_viewed INTEGER DEFAULT 0,
  total_actions INTEGER DEFAULT 0,

  -- Most used features (JSON)
  top_screens JSONB,

  updated_at TIMESTAMPTZ DEFAULT NOW(),

  PRIMARY KEY (user_id, app_platform)
);

-- Function to update user login stats
CREATE OR REPLACE FUNCTION update_user_login_stats()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO user_login_stats (
    user_id,
    total_logins,
    first_login_at,
    last_login_at,
    total_sessions
  ) VALUES (
    NEW.user_id,
    1,
    NEW.session_start,
    NEW.session_start,
    1
  )
  ON CONFLICT (user_id) DO UPDATE SET
    total_logins = user_login_stats.total_logins + 1,
    last_login_at = NEW.session_start,
    total_sessions = user_login_stats.total_sessions + 1,
    updated_at = NOW();

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_user_login_stats
  AFTER INSERT ON user_sessions
  FOR EACH ROW
  EXECUTE FUNCTION update_user_login_stats();

-- Function to update session duration when session ends
CREATE OR REPLACE FUNCTION update_session_duration()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.session_end IS NOT NULL AND OLD.session_end IS NULL THEN
    NEW.duration_seconds = EXTRACT(EPOCH FROM (NEW.session_end - NEW.session_start))::INTEGER;

    -- Update aggregated stats
    UPDATE user_login_stats
    SET
      total_session_duration_seconds = total_session_duration_seconds + NEW.duration_seconds,
      average_session_duration_seconds = (total_session_duration_seconds + NEW.duration_seconds) / total_sessions,
      longest_session_duration_seconds = GREATEST(longest_session_duration_seconds, NEW.duration_seconds),
      updated_at = NOW()
    WHERE user_id = NEW.user_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_session_duration
  BEFORE UPDATE ON user_sessions
  FOR EACH ROW
  EXECUTE FUNCTION update_session_duration();

-- Similar trigger for app sessions
CREATE TRIGGER trigger_update_app_session_duration
  BEFORE UPDATE ON app_sessions
  FOR EACH ROW
  EXECUTE FUNCTION update_session_duration();

-- Comments
COMMENT ON TABLE user_sessions IS 'Tracks web dashboard user sessions with login times and activity';
COMMENT ON TABLE user_actions IS 'Detailed log of user actions on web dashboard';
COMMENT ON TABLE user_login_stats IS 'Aggregated login and session statistics per user';
COMMENT ON TABLE app_sessions IS 'Tracks mobile app sessions (iOS & Android)';
COMMENT ON TABLE app_actions IS 'Detailed log of user actions in mobile apps';
COMMENT ON TABLE app_usage_stats IS 'Aggregated app usage statistics per user per platform';

-- Enable RLS (Row Level Security)
ALTER TABLE user_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_login_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_usage_stats ENABLE ROW LEVEL SECURITY;

-- RLS Policies (users can only see their own data, except employees/admins)
CREATE POLICY "Users can view own sessions"
  ON user_sessions FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own sessions"
  ON user_sessions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own sessions"
  ON user_sessions FOR UPDATE
  USING (auth.uid() = user_id);

-- Similar policies for other tables
CREATE POLICY "Users can view own actions"
  ON user_actions FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own actions"
  ON user_actions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view own stats"
  ON user_login_stats FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can view own app sessions"
  ON app_sessions FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own app sessions"
  ON app_sessions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own app sessions"
  ON app_sessions FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can view own app actions"
  ON app_actions FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own app actions"
  ON app_actions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view own app stats"
  ON app_usage_stats FOR SELECT
  USING (auth.uid() = user_id);

SELECT 'Analytics tables created successfully!' AS status;
