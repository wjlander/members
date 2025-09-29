/*
  # Email and Campaign Functions

  1. Email Campaign Management
    - Functions for sending campaigns
    - Recipient calculation
    - Performance tracking

  2. Subscription Management
    - Bulk subscription operations
    - Subscription analytics

  3. Email Analytics
    - Open rate calculations
    - Click tracking
    - Delivery statistics
*/

-- Function to get campaign recipients
CREATE OR REPLACE FUNCTION get_campaign_recipients(campaign_id UUID)
RETURNS TABLE(
    member_id UUID,
    name TEXT,
    email TEXT,
    association_name TEXT
) AS $$
DECLARE
    campaign_record RECORD;
BEGIN
    -- Get campaign details
    SELECT ec.*, a.name as assoc_name
    INTO campaign_record
    FROM email_campaigns ec
    JOIN associations a ON ec.association_id = a.id
    WHERE ec.id = campaign_id;
    
    IF campaign_record.mailing_list_id IS NOT NULL THEN
        -- Return subscribers to specific mailing list
        RETURN QUERY
        SELECT 
            m.id,
            m.name,
            m.email,
            campaign_record.assoc_name
        FROM mailing_list_subscriptions mls
        JOIN members m ON mls.member_id = m.id
        WHERE mls.mailing_list_id = campaign_record.mailing_list_id
        AND mls.is_active = TRUE
        AND m.status = 'active';
    ELSE
        -- Return all active members in association
        RETURN QUERY
        SELECT 
            m.id,
            m.name,
            m.email,
            campaign_record.assoc_name
        FROM members m
        WHERE m.association_id = campaign_record.association_id
        AND m.status = 'active';
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to calculate email campaign statistics
CREATE OR REPLACE FUNCTION calculate_campaign_stats(campaign_id UUID)
RETURNS TABLE(
    total_sent INTEGER,
    delivered INTEGER,
    opened INTEGER,
    clicked INTEGER,
    bounced INTEGER,
    delivery_rate NUMERIC,
    open_rate NUMERIC,
    click_rate NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::INTEGER as total_sent,
        COUNT(CASE WHEN edl.status = 'delivered' THEN 1 END)::INTEGER as delivered,
        COUNT(CASE WHEN edl.opened_at IS NOT NULL THEN 1 END)::INTEGER as opened,
        COUNT(CASE WHEN edl.clicked_at IS NOT NULL THEN 1 END)::INTEGER as clicked,
        COUNT(CASE WHEN edl.status = 'bounced' THEN 1 END)::INTEGER as bounced,
        CASE 
            WHEN COUNT(*) > 0 THEN 
                ROUND((COUNT(CASE WHEN edl.status = 'delivered' THEN 1 END)::NUMERIC / COUNT(*)::NUMERIC) * 100, 2)
            ELSE 0
        END as delivery_rate,
        CASE 
            WHEN COUNT(CASE WHEN edl.status = 'delivered' THEN 1 END) > 0 THEN 
                ROUND((COUNT(CASE WHEN edl.opened_at IS NOT NULL THEN 1 END)::NUMERIC / COUNT(CASE WHEN edl.status = 'delivered' THEN 1 END)::NUMERIC) * 100, 2)
            ELSE 0
        END as open_rate,
        CASE 
            WHEN COUNT(CASE WHEN edl.status = 'delivered' THEN 1 END) > 0 THEN 
                ROUND((COUNT(CASE WHEN edl.clicked_at IS NOT NULL THEN 1 END)::NUMERIC / COUNT(CASE WHEN edl.status = 'delivered' THEN 1 END)::NUMERIC) * 100, 2)
            ELSE 0
        END as click_rate
    FROM email_delivery_logs edl
    WHERE edl.campaign_id = calculate_campaign_stats.campaign_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to bulk subscribe members to mailing list
CREATE OR REPLACE FUNCTION bulk_subscribe_to_mailing_list(
    list_id UUID,
    member_ids UUID[]
)
RETURNS INTEGER AS $$
DECLARE
    member_id UUID;
    success_count INTEGER := 0;
BEGIN
    FOREACH member_id IN ARRAY member_ids LOOP
        BEGIN
            INSERT INTO mailing_list_subscriptions (mailing_list_id, member_id, is_active, subscribed_at)
            VALUES (list_id, member_id, TRUE, NOW())
            ON CONFLICT (mailing_list_id, member_id)
            DO UPDATE SET 
                is_active = TRUE,
                subscribed_at = NOW(),
                unsubscribed_at = NULL,
                updated_at = NOW();
            
            success_count := success_count + 1;
        EXCEPTION
            WHEN OTHERS THEN
                -- Log error but continue with other members
                CONTINUE;
        END;
    END LOOP;
    
    RETURN success_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get member subscription status
CREATE OR REPLACE FUNCTION get_member_subscriptions(member_user_id UUID)
RETURNS TABLE(
    mailing_list_id UUID,
    list_name TEXT,
    list_type mailing_list_type,
    is_subscribed BOOLEAN,
    subscribed_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ml.id,
        ml.name,
        ml.type,
        COALESCE(mls.is_active, FALSE) as is_subscribed,
        mls.subscribed_at
    FROM mailing_lists ml
    LEFT JOIN mailing_list_subscriptions mls ON (
        ml.id = mls.mailing_list_id AND 
        mls.member_id = (SELECT id FROM members WHERE user_id = member_user_id)
    )
    WHERE ml.association_id = (
        SELECT association_id FROM users WHERE id = member_user_id
    )
    AND ml.status = 'active'
    ORDER BY ml.name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to handle user profile creation from auth trigger
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO users (id, email, name, role)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'name', NEW.email),
        'member'
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to create user profile when auth user is created
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION handle_new_user();

-- Function to clean up old delivery logs (for maintenance)
CREATE OR REPLACE FUNCTION cleanup_old_delivery_logs(days_to_keep INTEGER DEFAULT 90)
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM email_delivery_logs
    WHERE created_at < NOW() - INTERVAL '1 day' * days_to_keep;
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;