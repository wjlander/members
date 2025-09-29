/*
  # Functions and Triggers

  1. Utility Functions
    - Auto-generate member IDs
    - Calculate subscriber counts
    - Handle auto-subscriptions

  2. Triggers
    - Update timestamps automatically
    - Auto-subscribe new members to lists
    - Generate member IDs

  3. Helper Functions
    - Subscription management
    - Statistics calculations
*/

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for updated_at
CREATE TRIGGER update_associations_updated_at
    BEFORE UPDATE ON associations
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_members_updated_at
    BEFORE UPDATE ON members
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_mailing_lists_updated_at
    BEFORE UPDATE ON mailing_lists
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_mailing_list_subscriptions_updated_at
    BEFORE UPDATE ON mailing_list_subscriptions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_email_campaigns_updated_at
    BEFORE UPDATE ON email_campaigns
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Function to generate member ID
CREATE OR REPLACE FUNCTION generate_member_id(association_code TEXT)
RETURNS TEXT AS $$
DECLARE
    new_id TEXT;
    counter INTEGER;
BEGIN
    -- Get the next sequence number for this association
    SELECT COALESCE(MAX(CAST(SUBSTRING(member_id FROM LENGTH(association_code) + 1) AS INTEGER)), 0) + 1
    INTO counter
    FROM members m
    JOIN associations a ON m.association_id = a.id
    WHERE a.code = association_code
    AND member_id ~ ('^' || association_code || '[0-9]+$');
    
    -- Generate new member ID
    new_id := association_code || LPAD(counter::TEXT, 4, '0');
    
    RETURN new_id;
END;
$$ LANGUAGE plpgsql;

-- Function to auto-generate member ID on insert
CREATE OR REPLACE FUNCTION auto_generate_member_id()
RETURNS TRIGGER AS $$
DECLARE
    assoc_code TEXT;
BEGIN
    -- Get association code
    SELECT code INTO assoc_code
    FROM associations
    WHERE id = NEW.association_id;
    
    -- Generate member ID if not provided
    IF NEW.member_id IS NULL OR NEW.member_id = '' THEN
        NEW.member_id := generate_member_id(assoc_code);
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-generate member ID
CREATE TRIGGER auto_generate_member_id_trigger
    BEFORE INSERT ON members
    FOR EACH ROW
    EXECUTE FUNCTION auto_generate_member_id();

-- Function to auto-subscribe new members to auto-subscribe lists
CREATE OR REPLACE FUNCTION auto_subscribe_new_member()
RETURNS TRIGGER AS $$
BEGIN
    -- Subscribe to all auto-subscribe lists in the association
    INSERT INTO mailing_list_subscriptions (mailing_list_id, member_id, is_active)
    SELECT ml.id, NEW.id, TRUE
    FROM mailing_lists ml
    WHERE ml.association_id = NEW.association_id
    AND ml.auto_subscribe_new_members = TRUE
    AND ml.status = 'active';
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for auto-subscription
CREATE TRIGGER auto_subscribe_new_member_trigger
    AFTER INSERT ON members
    FOR EACH ROW
    EXECUTE FUNCTION auto_subscribe_new_member();

-- Function to get mailing list subscriber count
CREATE OR REPLACE FUNCTION get_mailing_list_subscriber_count(list_id UUID)
RETURNS INTEGER AS $$
BEGIN
    RETURN (
        SELECT COUNT(*)
        FROM mailing_list_subscriptions
        WHERE mailing_list_id = list_id
        AND is_active = TRUE
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to subscribe member to mailing list
CREATE OR REPLACE FUNCTION subscribe_to_mailing_list(list_id UUID, member_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    INSERT INTO mailing_list_subscriptions (mailing_list_id, member_id, is_active, subscribed_at)
    VALUES (list_id, member_id, TRUE, NOW())
    ON CONFLICT (mailing_list_id, member_id)
    DO UPDATE SET 
        is_active = TRUE,
        subscribed_at = NOW(),
        unsubscribed_at = NULL,
        updated_at = NOW();
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to unsubscribe member from mailing list
CREATE OR REPLACE FUNCTION unsubscribe_from_mailing_list(list_id UUID, member_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE mailing_list_subscriptions
    SET is_active = FALSE,
        unsubscribed_at = NOW(),
        updated_at = NOW()
    WHERE mailing_list_id = list_id
    AND member_id = member_id;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get association statistics
CREATE OR REPLACE FUNCTION get_association_stats(assoc_id UUID)
RETURNS TABLE(
    total_members INTEGER,
    active_members INTEGER,
    pending_members INTEGER,
    inactive_members INTEGER,
    suspended_members INTEGER,
    total_mailing_lists INTEGER,
    total_campaigns INTEGER,
    total_emails_sent INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(m.*)::INTEGER as total_members,
        COUNT(CASE WHEN m.status = 'active' THEN 1 END)::INTEGER as active_members,
        COUNT(CASE WHEN m.status = 'pending' THEN 1 END)::INTEGER as pending_members,
        COUNT(CASE WHEN m.status = 'inactive' THEN 1 END)::INTEGER as inactive_members,
        COUNT(CASE WHEN m.status = 'suspended' THEN 1 END)::INTEGER as suspended_members,
        (SELECT COUNT(*) FROM mailing_lists WHERE association_id = assoc_id)::INTEGER as total_mailing_lists,
        (SELECT COUNT(*) FROM email_campaigns WHERE association_id = assoc_id)::INTEGER as total_campaigns,
        (SELECT COALESCE(SUM(recipient_count), 0) FROM email_campaigns WHERE association_id = assoc_id)::INTEGER as total_emails_sent
    FROM members m
    WHERE m.association_id = assoc_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;