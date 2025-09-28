/*
  # Row Level Security Policies

  This file contains all RLS policies for data isolation and security.
  Policies ensure users can only access data from their own association
  and based on their role permissions.
*/

-- Helper function to get current user's association
CREATE OR REPLACE FUNCTION get_user_association_id()
RETURNS UUID AS $$
BEGIN
    RETURN (SELECT association_id FROM users WHERE id = current_setting('app.current_user_id')::UUID);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper function to get current user's role
CREATE OR REPLACE FUNCTION get_user_role()
RETURNS user_role AS $$
BEGIN
    RETURN (SELECT role FROM users WHERE id = current_setting('app.current_user_id')::UUID);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper function to check if user is current user
CREATE OR REPLACE FUNCTION is_current_user(user_uuid UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN user_uuid = current_setting('app.current_user_id')::UUID;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Associations policies
CREATE POLICY "associations_select" ON associations
    FOR SELECT USING (
        get_user_role() = 'super_admin' OR 
        id = get_user_association_id()
    );

CREATE POLICY "associations_insert" ON associations
    FOR INSERT WITH CHECK (
        get_user_role() = 'super_admin'
    );

CREATE POLICY "associations_update" ON associations
    FOR UPDATE USING (
        get_user_role() = 'super_admin' OR 
        (get_user_role() = 'admin' AND id = get_user_association_id())
    );

CREATE POLICY "associations_delete" ON associations
    FOR DELETE USING (
        get_user_role() = 'super_admin'
    );

-- Users policies
CREATE POLICY "users_select" ON users
    FOR SELECT USING (
        get_user_role() = 'super_admin' OR
        association_id = get_user_association_id() OR
        is_current_user(id)
    );

CREATE POLICY "users_insert" ON users
    FOR INSERT WITH CHECK (
        get_user_role() = 'super_admin' OR
        (get_user_role() = 'admin' AND association_id = get_user_association_id())
    );

CREATE POLICY "users_update" ON users
    FOR UPDATE USING (
        is_current_user(id) OR
        get_user_role() = 'super_admin' OR
        (get_user_role() = 'admin' AND association_id = get_user_association_id())
    );

CREATE POLICY "users_delete" ON users
    FOR DELETE USING (
        is_current_user(id) OR
        get_user_role() = 'super_admin'
    );

-- Members policies
CREATE POLICY "members_select" ON members
    FOR SELECT USING (
        get_user_role() = 'super_admin' OR
        association_id = get_user_association_id() OR
        is_current_user(user_id)
    );

CREATE POLICY "members_insert" ON members
    FOR INSERT WITH CHECK (
        get_user_role() = 'super_admin' OR
        (get_user_role() = 'admin' AND association_id = get_user_association_id()) OR
        is_current_user(user_id)
    );

CREATE POLICY "members_update" ON members
    FOR UPDATE USING (
        get_user_role() = 'super_admin' OR
        (get_user_role() = 'admin' AND association_id = get_user_association_id()) OR
        (is_current_user(user_id) AND status = 'pending')
    );

CREATE POLICY "members_delete" ON members
    FOR DELETE USING (
        get_user_role() = 'super_admin' OR
        (get_user_role() = 'admin' AND association_id = get_user_association_id())
    );

-- Member payments policies
CREATE POLICY "member_payments_select" ON member_payments
    FOR SELECT USING (
        get_user_role() = 'super_admin' OR
        association_id = get_user_association_id() OR
        member_id IN (SELECT id FROM members WHERE is_current_user(user_id))
    );

CREATE POLICY "member_payments_insert" ON member_payments
    FOR INSERT WITH CHECK (
        get_user_role() = 'super_admin' OR
        (get_user_role() = 'admin' AND association_id = get_user_association_id())
    );

CREATE POLICY "member_payments_update" ON member_payments
    FOR UPDATE USING (
        get_user_role() = 'super_admin' OR
        (get_user_role() = 'admin' AND association_id = get_user_association_id())
    );

CREATE POLICY "member_payments_delete" ON member_payments
    FOR DELETE USING (
        get_user_role() = 'super_admin' OR
        (get_user_role() = 'admin' AND association_id = get_user_association_id())
    );

-- Announcements policies
CREATE POLICY "announcements_select" ON announcements
    FOR SELECT USING (
        get_user_role() = 'super_admin' OR
        association_id = get_user_association_id()
    );

CREATE POLICY "announcements_insert" ON announcements
    FOR INSERT WITH CHECK (
        get_user_role() = 'super_admin' OR
        (get_user_role() = 'admin' AND association_id = get_user_association_id())
    );

CREATE POLICY "announcements_update" ON announcements
    FOR UPDATE USING (
        get_user_role() = 'super_admin' OR
        (get_user_role() = 'admin' AND association_id = get_user_association_id()) OR
        is_current_user(author_id)
    );

CREATE POLICY "announcements_delete" ON announcements
    FOR DELETE USING (
        get_user_role() = 'super_admin' OR
        (get_user_role() = 'admin' AND association_id = get_user_association_id()) OR
        is_current_user(author_id)
    );

-- Mailing lists policies
CREATE POLICY "mailing_lists_select" ON mailing_lists
    FOR SELECT USING (
        get_user_role() = 'super_admin' OR
        association_id = get_user_association_id()
    );

CREATE POLICY "mailing_lists_insert" ON mailing_lists
    FOR INSERT WITH CHECK (
        get_user_role() = 'super_admin' OR
        (get_user_role() = 'admin' AND association_id = get_user_association_id())
    );

CREATE POLICY "mailing_lists_update" ON mailing_lists
    FOR UPDATE USING (
        get_user_role() = 'super_admin' OR
        (get_user_role() = 'admin' AND association_id = get_user_association_id())
    );

CREATE POLICY "mailing_lists_delete" ON mailing_lists
    FOR DELETE USING (
        get_user_role() = 'super_admin' OR
        (get_user_role() = 'admin' AND association_id = get_user_association_id())
    );

-- Mailing list subscriptions policies
CREATE POLICY "mailing_list_subscriptions_select" ON mailing_list_subscriptions
    FOR SELECT USING (
        get_user_role() = 'super_admin' OR
        mailing_list_id IN (SELECT id FROM mailing_lists WHERE association_id = get_user_association_id()) OR
        member_id IN (SELECT id FROM members WHERE is_current_user(user_id))
    );

CREATE POLICY "mailing_list_subscriptions_insert" ON mailing_list_subscriptions
    FOR INSERT WITH CHECK (
        get_user_role() = 'super_admin' OR
        mailing_list_id IN (SELECT id FROM mailing_lists WHERE association_id = get_user_association_id()) OR
        member_id IN (SELECT id FROM members WHERE is_current_user(user_id))
    );

CREATE POLICY "mailing_list_subscriptions_update" ON mailing_list_subscriptions
    FOR UPDATE USING (
        get_user_role() = 'super_admin' OR
        mailing_list_id IN (SELECT id FROM mailing_lists WHERE association_id = get_user_association_id()) OR
        member_id IN (SELECT id FROM members WHERE is_current_user(user_id))
    );

CREATE POLICY "mailing_list_subscriptions_delete" ON mailing_list_subscriptions
    FOR DELETE USING (
        get_user_role() = 'super_admin' OR
        mailing_list_id IN (SELECT id FROM mailing_lists WHERE association_id = get_user_association_id()) OR
        member_id IN (SELECT id FROM members WHERE is_current_user(user_id))
    );

-- Email campaigns policies
CREATE POLICY "email_campaigns_select" ON email_campaigns
    FOR SELECT USING (
        get_user_role() = 'super_admin' OR
        association_id = get_user_association_id()
    );

CREATE POLICY "email_campaigns_insert" ON email_campaigns
    FOR INSERT WITH CHECK (
        get_user_role() = 'super_admin' OR
        (get_user_role() = 'admin' AND association_id = get_user_association_id())
    );

CREATE POLICY "email_campaigns_update" ON email_campaigns
    FOR UPDATE USING (
        get_user_role() = 'super_admin' OR
        (get_user_role() = 'admin' AND association_id = get_user_association_id()) OR
        is_current_user(sender_id)
    );

CREATE POLICY "email_campaigns_delete" ON email_campaigns
    FOR DELETE USING (
        get_user_role() = 'super_admin' OR
        (get_user_role() = 'admin' AND association_id = get_user_association_id()) OR
        is_current_user(sender_id)
    );

-- Email delivery logs policies
CREATE POLICY "email_delivery_logs_select" ON email_delivery_logs
    FOR SELECT USING (
        get_user_role() = 'super_admin' OR
        campaign_id IN (SELECT id FROM email_campaigns WHERE association_id = get_user_association_id()) OR
        member_id IN (SELECT id FROM members WHERE is_current_user(user_id))
    );

CREATE POLICY "email_delivery_logs_insert" ON email_delivery_logs
    FOR INSERT WITH CHECK (
        get_user_role() = 'super_admin' OR
        campaign_id IN (SELECT id FROM email_campaigns WHERE association_id = get_user_association_id())
    );

CREATE POLICY "email_delivery_logs_update" ON email_delivery_logs
    FOR UPDATE USING (
        get_user_role() = 'super_admin' OR
        campaign_id IN (SELECT id FROM email_campaigns WHERE association_id = get_user_association_id())
    );

CREATE POLICY "email_delivery_logs_delete" ON email_delivery_logs
    FOR DELETE USING (
        get_user_role() = 'super_admin' OR
        campaign_id IN (SELECT id FROM email_campaigns WHERE association_id = get_user_association_id())
    );