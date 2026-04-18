-- Fix RLS policies for app_usage_stats table
-- Missing INSERT and UPDATE policies

-- Allow users to insert their own app usage stats
CREATE POLICY "Users can insert own app stats"
  ON app_usage_stats FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Allow users to update their own app usage stats
CREATE POLICY "Users can update own app stats"
  ON app_usage_stats FOR UPDATE
  USING (auth.uid() = user_id);

SELECT 'App usage stats RLS policies fixed!' AS status;
