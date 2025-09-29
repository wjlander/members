-- Create Super Admin User Script
-- This creates a super admin who can manage all associations

DO $$
DECLARE
    superadmin_user_id UUID;
BEGIN
    -- Create super admin user (no association required)
    INSERT INTO users (email, password_hash, name, role, association_id)
    VALUES (
        'superadmin@example.com',  -- CHANGE THIS EMAIL
        crypt('superadmin123', gen_salt('bf')),  -- CHANGE THIS PASSWORD
        'Super Administrator',
        'super_admin',
        NULL  -- No association required for super admin
    ) RETURNING id INTO superadmin_user_id;
    
    RAISE NOTICE 'Super admin user created successfully with email: superadmin@example.com';
    RAISE NOTICE 'User ID: %', superadmin_user_id;
END $$;

-- Verify the super admin user was created
SELECT u.email, u.name, u.role, u.association_id
FROM users u
WHERE u.role = 'super_admin';