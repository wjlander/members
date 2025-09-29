/*
  # Sample Data for Development

  1. Sample Associations
    - Create default associations for testing
    - Different types of organizations

  2. Sample Users
    - Super admin user
    - Association admin users
    - Sample members

  3. Sample Mailing Lists
    - Different types of lists
    - Auto-subscribe examples

  4. Notes
    - This is for development/testing only
    - Remove or modify for production
*/

-- Insert sample associations
INSERT INTO associations (name, code, description, status) VALUES
    ('Surrey Bell Ringers Association', 'SBRA', 'The Surrey Association of Church Bell Ringers', 'active'),
    ('Oxford Diocesan Guild', 'ODG', 'Oxford Diocesan Guild of Church Bell Ringers', 'active'),
    ('Kent County Association', 'KCA', 'Kent County Association of Change Ringers', 'active')
ON CONFLICT (code) DO NOTHING;

-- Insert sample mailing lists for each association
DO $$
DECLARE
    assoc_record RECORD;
BEGIN
    FOR assoc_record IN SELECT id, code FROM associations LOOP
        INSERT INTO mailing_lists (association_id, name, description, type, auto_subscribe_new_members, status) VALUES
            (assoc_record.id, 'General Announcements', 'Important updates and announcements', 'announcements', TRUE, 'active'),
            (assoc_record.id, 'Monthly Newsletter', 'Monthly newsletter with news and events', 'newsletter', FALSE, 'active'),
            (assoc_record.id, 'Event Notifications', 'Notifications about upcoming events and practices', 'events', FALSE, 'active'),
            (assoc_record.id, 'Social Events', 'Social gatherings and informal events', 'social', FALSE, 'active')
        ON CONFLICT (association_id, name) DO NOTHING;
    END LOOP;
END $$;

-- Note: In production, you would create your first super admin user through the Supabase dashboard
-- or through a secure setup process. This is just for development testing.

-- Create a sample super admin user (you should replace this with your actual admin)
-- This will only work if you manually create the auth.users record first in Supabase dashboard
/*
INSERT INTO users (id, email, name, role, association_id) VALUES
    ('00000000-0000-0000-0000-000000000001', 'admin@example.com', 'Super Administrator', 'super_admin', NULL)
ON CONFLICT (id) DO NOTHING;
*/