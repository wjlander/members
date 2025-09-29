/*
  # Fix Member ID Auto-Generation Issue

  This migration fixes the issue where member_id is not being auto-generated
  properly when creating member records, causing NOT NULL constraint violations.

  1. Updates
    - Fix the auto-generation trigger to work properly
    - Add a function to handle member creation with auto-generated member_id
    - Ensure the trigger fires before the NOT NULL constraint is checked

  2. Testing
    - Test the member creation process
    - Verify member_id is generated correctly
*/

-- Drop and recreate the member ID generation function with better logic
DROP FUNCTION IF EXISTS generate_member_id(VARCHAR(10)) CASCADE;
DROP FUNCTION IF EXISTS auto_generate_member_id() CASCADE;

-- Improved member ID generation function
CREATE OR REPLACE FUNCTION generate_member_id(association_code VARCHAR(10))
RETURNS VARCHAR(50) AS $$
DECLARE
    new_id VARCHAR(50);
    counter INTEGER;
    max_attempts INTEGER := 100;
    attempt INTEGER := 0;
BEGIN
    LOOP
        -- Get the next sequence number for this association
        SELECT COALESCE(MAX(
            CASE 
                WHEN member_id ~ ('^' || association_code || '[0-9]+$') 
                THEN CAST(SUBSTRING(member_id FROM LENGTH(association_code) + 1) AS INTEGER)
                ELSE 0
            END
        ), 0) + 1
        INTO counter
        FROM members m
        JOIN associations a ON m.association_id = a.id
        WHERE a.code = association_code;
        
        -- Generate the new member ID
        new_id := association_code || LPAD(counter::TEXT, 6, '0');
        
        -- Check if this ID already exists (safety check)
        IF NOT EXISTS (SELECT 1 FROM members WHERE member_id = new_id) THEN
            RETURN new_id;
        END IF;
        
        -- Increment counter and try again
        counter := counter + 1;
        attempt := attempt + 1;
        
        -- Prevent infinite loop
        IF attempt >= max_attempts THEN
            RAISE EXCEPTION 'Could not generate unique member ID after % attempts', max_attempts;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Improved auto-generation trigger function
CREATE OR REPLACE FUNCTION auto_generate_member_id()
RETURNS TRIGGER AS $$
DECLARE
    assoc_code VARCHAR(10);
BEGIN
    -- Only generate if member_id is not provided or is empty
    IF NEW.member_id IS NULL OR NEW.member_id = '' THEN
        -- Get association code
        SELECT code INTO assoc_code
        FROM associations
        WHERE id = NEW.association_id;
        
        IF assoc_code IS NULL THEN
            RAISE EXCEPTION 'Association not found for ID: %', NEW.association_id;
        END IF;
        
        -- Generate member ID
        NEW.member_id := generate_member_id(assoc_code);
        
        RAISE NOTICE 'Generated member_id: % for association: %', NEW.member_id, assoc_code;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate the trigger
DROP TRIGGER IF EXISTS trigger_auto_generate_member_id ON members;
CREATE TRIGGER trigger_auto_generate_member_id
    BEFORE INSERT ON members
    FOR EACH ROW
    EXECUTE FUNCTION auto_generate_member_id();

-- Test the member ID generation
DO $$
DECLARE
    test_assoc_id UUID;
    test_user_id UUID;
    test_member_id UUID;
    generated_member_id VARCHAR(50);
BEGIN
    -- Get the first association
    SELECT id INTO test_assoc_id FROM associations LIMIT 1;
    
    IF test_assoc_id IS NULL THEN
        RAISE NOTICE 'No associations found for testing';
        RETURN;
    END IF;
    
    -- Test member ID generation
    SELECT code INTO generated_member_id FROM associations WHERE id = test_assoc_id;
    generated_member_id := generate_member_id(generated_member_id);
    
    RAISE NOTICE 'Test member ID generation successful: %', generated_member_id;
END $$;