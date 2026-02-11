-- Fix audit log RLS to allow inserts from both authenticated and anon users

DROP POLICY IF EXISTS "System can insert audit logs" ON audit_log;
CREATE POLICY "System can insert audit logs"
    ON audit_log FOR INSERT
    TO authenticated, anon
    WITH CHECK (true);

-- Also allow the existing policies to work correctly
DROP POLICY IF EXISTS "Users can view their own audit logs" ON audit_log;
CREATE POLICY "Users can view their own audit logs"
    ON audit_log FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Admins can view all audit logs" ON audit_log;
CREATE POLICY "Admins can view all audit logs"
    ON audit_log FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

SELECT 'Audit log RLS fixed!' AS status;
