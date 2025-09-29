/*
  # Row Level Security Policies

  1. Security Setup
    - Enable RLS on all tables
    - Create policies for role-based access
    - Ensure data isolation between associations

  2. Access Control
    - Super admins can access all data
    - Admins can access their association's data
    - Members can access their own data and association info

  3. Policies
    - Read policies for viewing data
    - Write policies for creating/updating data
    - Delete policies for removing data
*/

-- Enable RLS on all tables
ALTER TABLE associations ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE members ENABLE ROW LEVEL SECURITY;
ALTER TABLE mailing_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE mailing_list_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_delivery_logs ENABLE ROW LEVEL SECURITY;

-- Helper function to get current user's role
CREATE OR REPLACE FUNCTION get_user_role()
RETURNS user_role AS $$
BEGIN
    RETURN (
        SELECT role 
        FROM users 
        WHERE id = auth.uid()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper function to get current user's association
CREATE OR REPLACE FUNCTION get_user_association()
RETURNS UUID AS $$
BEGIN
    RETURN (
        SELECT association_id 
        FROM users 
        WHERE id = auth.uid()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Associations policies
CREATE POLICY "Anyone can view active associations"
    ON associations FOR SELECT
    TO authenticated
    USING (status = 'active');

CREATE POLICY "Super admins can manage all associations"
    ON associations FOR ALL
    TO authenticated
    USING (get_user_role() = 'super_admin');

CREATE POLICY "Admins can update their association"
    ON associations FOR UPDATE
    TO authenticated
    USING (
        get_user_role() = 'admin' AND 
        id = get_user_association()
    );

-- Users policies
CREATE POLICY "Users can view their own profile"
    ON users FOR SELECT
    TO authenticated
    USING (id = auth.uid());

CREATE POLICY "Super admins can view all users"
    ON users FOR SELECT
    TO authenticated
    USING (get_user_role() = 'super_admin');

CREATE POLICY "Admins can view users in their association"
    ON users FOR SELECT
    TO authenticated
    USING (
        get_user_role() = 'admin' AND 
        association_id = get_user_association()
    );

CREATE POLICY "Users can update their own profile"
    ON users FOR UPDATE
    TO authenticated
    USING (id = auth.uid());

CREATE POLICY "Super admins can manage all users"
    ON users FOR ALL
    TO authenticated
    USING (get_user_role() = 'super_admin');

CREATE POLICY "Anyone can create user profile"
    ON users FOR INSERT
    TO authenticated
    WITH CHECK (id = auth.uid());

-- Members policies
CREATE POLICY "Members can view their own data"
    ON members FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());

CREATE POLICY "Admins can view members in their association"
    ON members FOR SELECT
    TO authenticated
    USING (
        get_user_role() IN ('admin', 'super_admin') AND
        (get_user_role() = 'super_admin' OR association_id = get_user_association())
    );

CREATE POLICY "Anyone can create member profile"
    ON members FOR INSERT
    TO authenticated
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "Members can update their own profile"
    ON members FOR UPDATE
    TO authenticated
    USING (user_id = auth.uid());

CREATE POLICY "Admins can update members in their association"
    ON members FOR UPDATE
    TO authenticated
    USING (
        get_user_role() IN ('admin', 'super_admin') AND
        (get_user_role() = 'super_admin' OR association_id = get_user_association())
    );

CREATE POLICY "Admins can delete members in their association"
    ON members FOR DELETE
    TO authenticated
    USING (
        get_user_role() IN ('admin', 'super_admin') AND
        (get_user_role() = 'super_admin' OR association_id = get_user_association())
    );

-- Mailing lists policies
CREATE POLICY "Members can view mailing lists in their association"
    ON mailing_lists FOR SELECT
    TO authenticated
    USING (
        association_id = get_user_association() OR
        get_user_role() = 'super_admin'
    );

CREATE POLICY "Admins can manage mailing lists in their association"
    ON mailing_lists FOR ALL
    TO authenticated
    USING (
        get_user_role() IN ('admin', 'super_admin') AND
        (get_user_role() = 'super_admin' OR association_id = get_user_association())
    );

-- Mailing list subscriptions policies
CREATE POLICY "Members can view their own subscriptions"
    ON mailing_list_subscriptions FOR SELECT
    TO authenticated
    USING (
        member_id IN (
            SELECT id FROM members WHERE user_id = auth.uid()
        ) OR
        get_user_role() IN ('admin', 'super_admin')
    );

CREATE POLICY "Members can manage their own subscriptions"
    ON mailing_list_subscriptions FOR ALL
    TO authenticated
    USING (
        member_id IN (
            SELECT id FROM members WHERE user_id = auth.uid()
        ) OR
        get_user_role() IN ('admin', 'super_admin')
    );

-- Email campaigns policies
CREATE POLICY "Members can view campaigns sent to them"
    ON email_campaigns FOR SELECT
    TO authenticated
    USING (
        association_id = get_user_association() OR
        get_user_role() = 'super_admin'
    );

CREATE POLICY "Admins can manage campaigns in their association"
    ON email_campaigns FOR ALL
    TO authenticated
    USING (
        get_user_role() IN ('admin', 'super_admin') AND
        (get_user_role() = 'super_admin' OR association_id = get_user_association())
    );

-- Email delivery logs policies
CREATE POLICY "Admins can view delivery logs for their campaigns"
    ON email_delivery_logs FOR SELECT
    TO authenticated
    USING (
        campaign_id IN (
            SELECT id FROM email_campaigns 
            WHERE association_id = get_user_association() OR get_user_role() = 'super_admin'
        )
    );

CREATE POLICY "System can manage delivery logs"
    ON email_delivery_logs FOR ALL
    TO authenticated
    USING (
        get_user_role() IN ('admin', 'super_admin')
    );