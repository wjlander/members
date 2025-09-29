-- Create First Admin User Script
-- Run this to create your initial admin user

-- First, let's check if we have any associations
SELECT id, name, code FROM associations;

-- If no associations exist, create one
INSERT INTO associations (name, code, description, status) 
VALUES ('Sample Bell Ringing Association', 'SBRA', 'Initial association for setup', 'active')
ON CONFLICT (code) DO NOTHING;

-- Get the association ID (replace with actual ID from above query)
-- Create the first admin user
DO $$
DECLARE
    assoc_id UUID;
    admin_user_id UUID;
BEGIN
    -- Get the first association ID
    SELECT id INTO assoc_id FROM associations LIMIT 1;
    
    -- Create admin user (replace email and password as needed)
    INSERT INTO users (email, password_hash, name, role, association_id)
    VALUES (
        'admin@example.com',  -- CHANGE THIS EMAIL
        crypt('admin123', gen_salt('bf')),  -- CHANGE THIS PASSWORD
        'System Administrator',
        'admin',
        assoc_id
    ) RETURNING id INTO admin_user_id;
    
    -- Create corresponding member record
    INSERT INTO members (user_id, association_id, name, email, status)
    VALUES (
        admin_user_id,
        assoc_id,
        'System Administrator',
        'admin@example.com',  -- CHANGE THIS EMAIL
        'active'
    );
    
    RAISE NOTICE 'Admin user created successfully with email: admin@example.com';
END $$;

-- Verify the admin user was created
SELECT u.email, u.name, u.role, a.name as association_name
FROM users u
JOIN associations a ON u.association_id = a.id
WHERE u.role = 'admin';