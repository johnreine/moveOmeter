-- Automatically create user profile when user signs up
-- This avoids RLS issues during registration

-- Function to create profile automatically
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.user_profiles (id, role, full_name, email, is_active)
    VALUES (
        NEW.id,
        'caretaker', -- Default role
        COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email),
        NEW.email,
        true
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger on auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- Now we can simplify the RLS policies since profile creation is automatic
-- Remove the INSERT policy (no longer needed from client side)
DROP POLICY IF EXISTS "Users can insert their own profile" ON user_profiles;

-- Keep the existing SELECT and UPDATE policies

SELECT 'Auto-profile creation trigger installed!' AS status;
