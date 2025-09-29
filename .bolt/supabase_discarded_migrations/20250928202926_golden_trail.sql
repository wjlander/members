/*
  # Database Functions and Triggers

  This file contains utility functions, stored procedures, and triggers
  for business logic and data integrity.
*/

-- Function to generate member ID
CREATE OR REPLACE FUNCTION generate_member_id(association_code VARCHAR(10))
RETURNS VARCHAR(50) AS $$
DECLARE
    new_id VARCHAR(50);
    counter INTEGER;
BEGIN
    -- Get the next sequence number for this association
    SELECT COALESCE(MAX(CAST(SUBSTRING(member_id FROM LENGTH(association_code) + 1) AS INTEGER)), 0) + 1
    INTO counter
    FROM members m
    JOIN associations a ON m.association_id = a.id
    WHERE a.code = association_code
    AND member_id ~ ('^' || association_code || '[0-9]+$');
    
    -- Generate the new member ID
    new_id := association_code || LPAD(counter::TEXT, 6, '0');
    
    RETURN new_id;
END;
$$ LANGUAGE plpgsql;

-- Function to auto-generate member ID on insert
CREATE OR REPLACE FUNCTION auto_generate_member_id()
RETURNS TRIGGER AS $$
DECLARE
    assoc_code VARCHAR(10);
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
CREATE TRIGGER trigger_auto_generate_member_id
    BEFORE INSERT ON members
    FOR EACH ROW
    EXECUTE FUNCTION auto_generate_member_id();

-- Function to auto-subscribe new members to mailing lists
CREATE OR REPLACE FUNCTION auto_subscribe_member()
RETURNS TRIGGER AS $$
BEGIN
    -- Auto-subscribe to mailing lists that have auto_subscribe_new_members = true
    INSERT INTO mailing_list_subscriptions (mailing_list_id, member_id)
    SELECT ml.id, NEW.id
    FROM mailing_lists ml
    WHERE ml.association_id = NEW.association_id
    AND ml.auto_subscribe_new_members = true
    AND ml.status = 'active';
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-subscribe new members
CREATE TRIGGER trigger_auto_subscribe_member
    AFTER INSERT ON members
    FOR EACH ROW
    EXECUTE FUNCTION auto_subscribe_member();

-- Function to update campaign statistics
CREATE OR REPLACE FUNCTION update_campaign_stats()
RETURNS TRIGGER AS $$
BEGIN
    -- Update campaign statistics based on delivery log changes
    IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
        UPDATE email_campaigns
        SET 
            delivered_count = (
                SELECT COUNT(*) FROM email_delivery_logs 
                WHERE campaign_id = NEW.campaign_id AND status = 'delivered'
            ),
            opened_count = (
                SELECT COUNT(*) FROM email_delivery_logs 
                WHERE campaign_id = NEW.campaign_id AND opened_at IS NOT NULL
            ),
            clicked_count = (
                SELECT COUNT(*) FROM email_delivery_logs 
                WHERE campaign_id = NEW.campaign_id AND clicked_at IS NOT NULL
            ),
            bounced_count = (
                SELECT COUNT(*) FROM email_delivery_logs 
                WHERE campaign_id = NEW.campaign_id AND status = 'bounced'
            )
        WHERE id = NEW.campaign_id;
        
        RETURN NEW;
    END IF;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update campaign statistics
CREATE TRIGGER trigger_update_campaign_stats
    AFTER INSERT OR UPDATE ON email_delivery_logs
    FOR EACH ROW
    EXECUTE FUNCTION update_campaign_stats();

-- Function to validate member email matches user email
CREATE OR REPLACE FUNCTION validate_member_email()
RETURNS TRIGGER AS $$
BEGIN
    -- Ensure member email matches user email
    IF NEW.email != (SELECT email FROM users WHERE id = NEW.user_id) THEN
        RAISE EXCEPTION 'Member email must match user email';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to validate member email
CREATE TRIGGER trigger_validate_member_email
    BEFORE INSERT OR UPDATE ON members
    FOR EACH ROW
    EXECUTE FUNCTION validate_member_email();

-- Function to prevent duplicate active subscriptions
CREATE OR REPLACE FUNCTION prevent_duplicate_subscriptions()
RETURNS TRIGGER AS $$
BEGIN
    -- Check if there's already an active subscription
    IF EXISTS (
        SELECT 1 FROM mailing_list_subscriptions
        WHERE mailing_list_id = NEW.mailing_list_id
        AND member_id = NEW.member_id
        AND is_active = true
        AND id != COALESCE(NEW.id, uuid_generate_v4())
    ) THEN
        RAISE EXCEPTION 'Member is already subscribed to this mailing list';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to prevent duplicate subscriptions
CREATE TRIGGER trigger_prevent_duplicate_subscriptions
    BEFORE INSERT OR UPDATE ON mailing_list_subscriptions
    FOR EACH ROW
    EXECUTE FUNCTION prevent_duplicate_subscriptions();

-- Function to get member statistics for an association
CREATE OR REPLACE FUNCTION get_association_stats(assoc_id UUID)
RETURNS TABLE (
    total_members INTEGER,
    active_members INTEGER,
    pending_members INTEGER,
    inactive_members INTEGER,
    suspended_members INTEGER,
    monthly_revenue DECIMAL(10,2),
    overdue_payments INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::INTEGER as total_members,
        COUNT(CASE WHEN status = 'active' THEN 1 END)::INTEGER as active_members,
        COUNT(CASE WHEN status = 'pending' THEN 1 END)::INTEGER as pending_members,
        COUNT(CASE WHEN status = 'inactive' THEN 1 END)::INTEGER as inactive_members,
        COUNT(CASE WHEN status = 'suspended' THEN 1 END)::INTEGER as suspended_members,
        COALESCE((
            SELECT SUM(amount)
            FROM member_payments mp
            WHERE mp.association_id = assoc_id
            AND mp.status = 'paid'
            AND mp.paid_date >= date_trunc('month', CURRENT_DATE)
        ), 0) as monthly_revenue,
        COALESCE((
            SELECT COUNT(*)
            FROM member_payments mp
            WHERE mp.association_id = assoc_id
            AND mp.status = 'overdue'
        ), 0)::INTEGER as overdue_payments
    FROM members m
    WHERE m.association_id = assoc_id;
END;
$$ LANGUAGE plpgsql;

-- Function to get mailing list subscriber count
CREATE OR REPLACE FUNCTION get_mailing_list_subscriber_count(list_id UUID)
RETURNS INTEGER AS $$
BEGIN
    RETURN (
        SELECT COUNT(*)::INTEGER
        FROM mailing_list_subscriptions
        WHERE mailing_list_id = list_id
        AND is_active = true
    );
END;
$$ LANGUAGE plpgsql;

-- Function to unsubscribe from mailing list
CREATE OR REPLACE FUNCTION unsubscribe_from_mailing_list(list_id UUID, member_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE mailing_list_subscriptions
    SET 
        is_active = false,
        unsubscribed_at = NOW()
    WHERE mailing_list_id = list_id
    AND member_id = member_id
    AND is_active = true;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Function to resubscribe to mailing list
CREATE OR REPLACE FUNCTION resubscribe_to_mailing_list(list_id UUID, member_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    -- Try to reactivate existing subscription
    UPDATE mailing_list_subscriptions
    SET 
        is_active = true,
        unsubscribed_at = NULL,
        subscribed_at = NOW()
    WHERE mailing_list_id = list_id
    AND member_id = member_id
    AND is_active = false;
    
    -- If no existing subscription, create new one
    IF NOT FOUND THEN
        INSERT INTO mailing_list_subscriptions (mailing_list_id, member_id)
        VALUES (list_id, member_id);
    END IF;
    
    RETURN true;
END;
$$ LANGUAGE plpgsql;

-- Function to clean up old email delivery logs
CREATE OR REPLACE FUNCTION cleanup_old_email_logs()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM email_delivery_logs
    WHERE created_at < NOW() - INTERVAL '90 days';
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;