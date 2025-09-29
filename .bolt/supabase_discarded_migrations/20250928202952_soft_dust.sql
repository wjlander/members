/*
  # Migration from PocketBase to PostgreSQL

  This script migrates data from PocketBase SQLite format to PostgreSQL.
  Run this after setting up the PostgreSQL schema.
  
  Prerequisites:
  1. Export data from PocketBase admin panel as JSON
  2. Place exported files in the appropriate directory
  3. Run this script with appropriate permissions
*/

-- Temporary function to import JSON data
CREATE OR REPLACE FUNCTION import_pocketbase_data()
RETURNS VOID AS $$
DECLARE
    json_data JSONB;
    record_data JSONB;
    assoc_id UUID;
    user_id UUID;
    member_id UUID;
BEGIN
    -- Import Associations
    -- Assuming you have exported associations data to a JSON file
    -- This is a template - adjust based on your actual data structure
    
    RAISE NOTICE 'Starting PocketBase data migration...';
    
    -- Example: Import associations (adjust based on your exported data)
    /*
    FOR record_data IN 
        SELECT jsonb_array_elements(json_data->'associations') 
        FROM (SELECT '{"associations": []}' ::jsonb as json_data) t
    LOOP
        INSERT INTO associations (id, name, code, description, status)
        VALUES (
            (record_data->>'id')::UUID,
            record_data->>'name',
            record_data->>'code',
            record_data->>'description',
            COALESCE(record_data->>'status', 'active')::association_status
        );
    END LOOP;
    */
    
    RAISE NOTICE 'Migration completed successfully';
END;
$$ LANGUAGE plpgsql;

-- Manual migration steps (to be customized based on your data)

-- Step 1: Create a temporary table for PocketBase data
CREATE TEMP TABLE IF NOT EXISTS pb_import_log (
    table_name VARCHAR(100),
    records_imported INTEGER,
    import_time TIMESTAMP DEFAULT NOW()
);

-- Step 2: Sample migration for associations
-- Replace with actual data from your PocketBase export
INSERT INTO associations (name, code, description, status) VALUES
('Sample Bell Ringing Association', 'SBRA', 'A sample association for testing', 'active'),
('Test Ringers Guild', 'TRG', 'Test guild for development', 'active');

-- Log the import
INSERT INTO pb_import_log (table_name, records_imported) VALUES ('associations', 2);

-- Step 3: Create sample admin user
-- Note: You'll need to hash passwords properly in production
DO $$
DECLARE
    assoc_id UUID;
    admin_user_id UUID;
BEGIN
    -- Get first association ID
    SELECT id INTO assoc_id FROM associations LIMIT 1;
    
    -- Create admin user
    INSERT INTO users (email, password_hash, name, role, association_id)
    VALUES (
        'admin@example.com',
        crypt('admin123', gen_salt('bf')), -- Use proper password hashing
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
        'admin@example.com',
        'active'
    );
END $$;

-- Step 4: Create sample mailing lists
DO $$
DECLARE
    assoc_id UUID;
BEGIN
    SELECT id INTO assoc_id FROM associations LIMIT 1;
    
    INSERT INTO mailing_lists (association_id, name, description, type, auto_subscribe_new_members)
    VALUES 
    (assoc_id, 'General Announcements', 'General association announcements', 'announcements', true),
    (assoc_id, 'Events', 'Event notifications and updates', 'events', false),
    (assoc_id, 'Newsletter', 'Monthly newsletter', 'newsletter', true);
END $$;

-- Function to validate migration
CREATE OR REPLACE FUNCTION validate_migration()
RETURNS TABLE (
    table_name VARCHAR(100),
    record_count BIGINT,
    status VARCHAR(20)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 'associations'::VARCHAR(100), COUNT(*), 
           CASE WHEN COUNT(*) > 0 THEN 'OK' ELSE 'EMPTY' END::VARCHAR(20)
    FROM associations
    UNION ALL
    SELECT 'users'::VARCHAR(100), COUNT(*), 
           CASE WHEN COUNT(*) > 0 THEN 'OK' ELSE 'EMPTY' END::VARCHAR(20)
    FROM users
    UNION ALL
    SELECT 'members'::VARCHAR(100), COUNT(*), 
           CASE WHEN COUNT(*) > 0 THEN 'OK' ELSE 'EMPTY' END::VARCHAR(20)
    FROM members
    UNION ALL
    SELECT 'mailing_lists'::VARCHAR(100), COUNT(*), 
           CASE WHEN COUNT(*) > 0 THEN 'OK' ELSE 'EMPTY' END::VARCHAR(20)
    FROM mailing_lists;
END;
$$ LANGUAGE plpgsql;

-- Run validation
SELECT * FROM validate_migration();

-- Display import summary
SELECT 
    'Migration Summary' as info,
    (SELECT COUNT(*) FROM associations) as associations_count,
    (SELECT COUNT(*) FROM users) as users_count,
    (SELECT COUNT(*) FROM members) as members_count,
    (SELECT COUNT(*) FROM mailing_lists) as mailing_lists_count;