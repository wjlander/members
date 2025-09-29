/*
  # Complete Membership Management System Setup

  This migration sets up the complete database schema for the membership management system.
  
  ## Tables Created:
  1. associations - Organization management
  2. users - User profiles (extends auth.users)
  3. members - Member data and profiles
  4. mailing_lists - Email list management
  5. mailing_list_subscriptions - Member subscriptions
  6. email_campaigns - Email campaign management
  7. email_delivery_logs - Email tracking and analytics

  ## Security:
  - Row Level Security enabled on all tables
  - Role-based access policies
  - Data isolation between associations

  ## Functions:
  - Auto member ID generation
  - Auto-subscription handling
  - Statistics functions
*/

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Create custom types
DO $$ BEGIN
    CREATE TYPE user_role AS ENUM ('super_admin', 'admin', 'member');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE member_status AS ENUM ('pending', 'active', 'inactive', 'suspended');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE membership_type AS ENUM ('regular', 'premium', 'student', 'senior', 'honorary');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE mailing_list_type AS ENUM ('general', 'announcements', 'events', 'newsletter', 'urgent', 'social');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE campaign_status AS ENUM ('draft', 'scheduled', 'sending', 'sent', 'failed');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Create associations table
CREATE TABLE IF NOT EXISTS associations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    code TEXT NOT NULL UNIQUE,
    description TEXT,
    settings JSONB DEFAULT '{}',
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create users table (extends Supabase auth.users)
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    name TEXT NOT NULL,
    role user_role DEFAULT 'member',
    association_id UUID REFERENCES associations(id) ON DELETE SET NULL,
    avatar_url TEXT,
    email_verified BOOLEAN DEFAULT false,
    last_login TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create members table
CREATE TABLE IF NOT EXISTS members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    association_id UUID NOT NULL REFERENCES associations(id) ON DELETE CASCADE,
    member_id TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    email TEXT NOT NULL,
    phone TEXT,
    address TEXT,
    date_of_birth DATE,
    status member_status DEFAULT 'pending',
    membership_type membership_type DEFAULT 'regular',
    join_date DATE DEFAULT CURRENT_DATE,
    notes TEXT,
    documents JSONB DEFAULT '[]',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, association_id)
);

-- Create mailing lists table
CREATE TABLE IF NOT EXISTS mailing_lists (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    association_id UUID NOT NULL REFERENCES associations(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    type mailing_list_type DEFAULT 'general',
    moderator_email TEXT,
    auto_subscribe_new_members BOOLEAN DEFAULT false,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(association_id, name)
);

-- Create mailing list subscriptions table
CREATE TABLE IF NOT EXISTS mailing_list_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    mailing_list_id UUID NOT NULL REFERENCES mailing_lists(id) ON DELETE CASCADE,
    member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
    subscribed_at TIMESTAMPTZ DEFAULT NOW(),
    unsubscribed_at TIMESTAMPTZ,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(mailing_list_id, member_id)
);

-- Create email campaigns table
CREATE TABLE IF NOT EXISTS email_campaigns (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    association_id UUID NOT NULL REFERENCES associations(id) ON DELETE CASCADE,
    mailing_list_id UUID REFERENCES mailing_lists(id) ON DELETE SET NULL,
    sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    subject TEXT NOT NULL,
    content TEXT NOT NULL,
    template_name TEXT,
    scheduled_at TIMESTAMPTZ,
    sent_at TIMESTAMPTZ,
    status campaign_status DEFAULT 'draft',
    recipient_count INTEGER DEFAULT 0,
    delivered_count INTEGER DEFAULT 0,
    opened_count INTEGER DEFAULT 0,
    clicked_count INTEGER DEFAULT 0,
    bounced_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create email delivery logs table
CREATE TABLE IF NOT EXISTS email_delivery_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID NOT NULL REFERENCES email_campaigns(id) ON DELETE CASCADE,
    member_id UUID REFERENCES members(id) ON DELETE SET NULL,
    email TEXT NOT NULL,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'delivered', 'bounced', 'failed')),
    resend_message_id TEXT,
    delivered_at TIMESTAMPTZ,
    opened_at TIMESTAMPTZ,
    clicked_at TIMESTAMPTZ,
    bounced_at TIMESTAMPTZ,
    error_message TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_users_association_id ON users(association_id);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);

CREATE INDEX IF NOT EXISTS idx_members_association_id ON members(association_id);
CREATE INDEX IF NOT EXISTS idx_members_user_id ON members(user_id);
CREATE INDEX IF NOT EXISTS idx_members_status ON members(status);
CREATE INDEX IF NOT EXISTS idx_members_email ON members(email);
CREATE INDEX IF NOT EXISTS idx_members_member_id ON members(member_id);

CREATE INDEX IF NOT EXISTS idx_mailing_lists_association_id ON mailing_lists(association_id);
CREATE INDEX IF NOT EXISTS idx_mailing_lists_status ON mailing_lists(status);

CREATE INDEX IF NOT EXISTS idx_subscriptions_mailing_list_id ON mailing_list_subscriptions(mailing_list_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_member_id ON mailing_list_subscriptions(member_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_active ON mailing_list_subscriptions(is_active);

CREATE INDEX IF NOT EXISTS idx_campaigns_association_id ON email_campaigns(association_id);
CREATE INDEX IF NOT EXISTS idx_campaigns_status ON email_campaigns(status);
CREATE INDEX IF NOT EXISTS idx_campaigns_sent_at ON email_campaigns(sent_at);

CREATE INDEX IF NOT EXISTS idx_delivery_logs_campaign_id ON email_delivery_logs(campaign_id);
CREATE INDEX IF NOT EXISTS idx_delivery_logs_member_id ON email_delivery_logs(member_id);
CREATE INDEX IF NOT EXISTS idx_delivery_logs_status ON email_delivery_logs(status);

-- Enable Row Level Security
ALTER TABLE associations ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE members ENABLE ROW LEVEL SECURITY;
ALTER TABLE mailing_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE mailing_list_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_delivery_logs ENABLE ROW LEVEL SECURITY;

-- RLS Policies for associations
CREATE POLICY "Public associations are viewable by everyone" ON associations
    FOR SELECT USING (status = 'active');

CREATE POLICY "Super admins can manage all associations" ON associations
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = auth.uid() 
            AND users.role = 'super_admin'
        )
    );

CREATE POLICY "Admins can view their association" ON associations
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = auth.uid() 
            AND users.association_id = associations.id
            AND users.role IN ('admin', 'super_admin')
        )
    );

CREATE POLICY "Admins can update their association" ON associations
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = auth.uid() 
            AND users.association_id = associations.id
            AND users.role IN ('admin', 'super_admin')
        )
    );

-- RLS Policies for users
CREATE POLICY "Users can view their own profile" ON users
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Super admins can view all users" ON users
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM users u 
            WHERE u.id = auth.uid() 
            AND u.role = 'super_admin'
        )
    );

CREATE POLICY "Admins can view users in their association" ON users
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM users u 
            WHERE u.id = auth.uid() 
            AND u.association_id = users.association_id
            AND u.role IN ('admin', 'super_admin')
        )
    );

CREATE POLICY "Users can update their own profile" ON users
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Super admins can manage all users" ON users
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM users u 
            WHERE u.id = auth.uid() 
            AND u.role = 'super_admin'
        )
    );

-- RLS Policies for members
CREATE POLICY "Members can view their own record" ON members
    FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Admins can view members in their association" ON members
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = auth.uid() 
            AND users.association_id = members.association_id
            AND users.role IN ('admin', 'super_admin')
        )
    );

CREATE POLICY "Super admins can view all members" ON members
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = auth.uid() 
            AND users.role = 'super_admin'
        )
    );

CREATE POLICY "Users can create their own member record" ON members
    FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "Members can update their own record" ON members
    FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY "Admins can manage members in their association" ON members
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = auth.uid() 
            AND users.association_id = members.association_id
            AND users.role IN ('admin', 'super_admin')
        )
    );

-- RLS Policies for mailing lists
CREATE POLICY "Members can view mailing lists in their association" ON mailing_lists
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = auth.uid() 
            AND users.association_id = mailing_lists.association_id
        )
    );

CREATE POLICY "Admins can manage mailing lists in their association" ON mailing_lists
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = auth.uid() 
            AND users.association_id = mailing_lists.association_id
            AND users.role IN ('admin', 'super_admin')
        )
    );

-- RLS Policies for subscriptions
CREATE POLICY "Members can view their own subscriptions" ON mailing_list_subscriptions
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM members 
            WHERE members.id = mailing_list_subscriptions.member_id
            AND members.user_id = auth.uid()
        )
    );

CREATE POLICY "Members can manage their own subscriptions" ON mailing_list_subscriptions
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM members 
            WHERE members.id = mailing_list_subscriptions.member_id
            AND members.user_id = auth.uid()
        )
    );

CREATE POLICY "Admins can view subscriptions in their association" ON mailing_list_subscriptions
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM mailing_lists ml
            JOIN users u ON u.association_id = ml.association_id
            WHERE ml.id = mailing_list_subscriptions.mailing_list_id
            AND u.id = auth.uid()
            AND u.role IN ('admin', 'super_admin')
        )
    );

CREATE POLICY "Admins can manage subscriptions in their association" ON mailing_list_subscriptions
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM mailing_lists ml
            JOIN users u ON u.association_id = ml.association_id
            WHERE ml.id = mailing_list_subscriptions.mailing_list_id
            AND u.id = auth.uid()
            AND u.role IN ('admin', 'super_admin')
        )
    );

-- RLS Policies for email campaigns
CREATE POLICY "Admins can view campaigns in their association" ON email_campaigns
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = auth.uid() 
            AND users.association_id = email_campaigns.association_id
            AND users.role IN ('admin', 'super_admin')
        )
    );

CREATE POLICY "Admins can manage campaigns in their association" ON email_campaigns
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = auth.uid() 
            AND users.association_id = email_campaigns.association_id
            AND users.role IN ('admin', 'super_admin')
        )
    );

-- RLS Policies for delivery logs
CREATE POLICY "Admins can view delivery logs for their campaigns" ON email_delivery_logs
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM email_campaigns ec
            JOIN users u ON u.association_id = ec.association_id
            WHERE ec.id = email_delivery_logs.campaign_id
            AND u.id = auth.uid()
            AND u.role IN ('admin', 'super_admin')
        )
    );

-- Create functions
CREATE OR REPLACE FUNCTION generate_member_id(association_code TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    new_id TEXT;
    counter INTEGER;
BEGIN
    -- Get the next sequence number for this association
    SELECT COALESCE(MAX(CAST(SUBSTRING(member_id FROM LENGTH(association_code) + 1) AS INTEGER)), 0) + 1
    INTO counter
    FROM members m
    JOIN associations a ON m.association_id = a.id
    WHERE a.code = association_code;
    
    -- Format: ASSOC001, ASSOC002, etc.
    new_id := association_code || LPAD(counter::TEXT, 3, '0');
    
    RETURN new_id;
END;
$$;

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
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
$$;

-- Create trigger for new user creation
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Function to auto-subscribe new members
CREATE OR REPLACE FUNCTION handle_new_member()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Auto-subscribe to mailing lists that have auto_subscribe_new_members = true
    INSERT INTO mailing_list_subscriptions (mailing_list_id, member_id, is_active)
    SELECT ml.id, NEW.id, true
    FROM mailing_lists ml
    WHERE ml.association_id = NEW.association_id
    AND ml.auto_subscribe_new_members = true
    AND ml.status = 'active';
    
    RETURN NEW;
END;
$$;

-- Create trigger for new member auto-subscription
DROP TRIGGER IF EXISTS on_member_created ON members;
CREATE TRIGGER on_member_created
    AFTER INSERT ON members
    FOR EACH ROW EXECUTE FUNCTION handle_new_member();

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

-- Create updated_at triggers
DROP TRIGGER IF EXISTS update_associations_updated_at ON associations;
CREATE TRIGGER update_associations_updated_at
    BEFORE UPDATE ON associations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_members_updated_at ON members;
CREATE TRIGGER update_members_updated_at
    BEFORE UPDATE ON members
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_mailing_lists_updated_at ON mailing_lists;
CREATE TRIGGER update_mailing_lists_updated_at
    BEFORE UPDATE ON mailing_lists
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_subscriptions_updated_at ON mailing_list_subscriptions;
CREATE TRIGGER update_subscriptions_updated_at
    BEFORE UPDATE ON mailing_list_subscriptions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_campaigns_updated_at ON email_campaigns;
CREATE TRIGGER update_campaigns_updated_at
    BEFORE UPDATE ON email_campaigns
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Statistics functions
CREATE OR REPLACE FUNCTION get_association_stats(assoc_id UUID)
RETURNS TABLE (
    total_members BIGINT,
    active_members BIGINT,
    pending_members BIGINT,
    inactive_members BIGINT,
    suspended_members BIGINT,
    total_mailing_lists BIGINT,
    total_campaigns BIGINT,
    total_emails_sent BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) as total_members,
        COUNT(*) FILTER (WHERE m.status = 'active') as active_members,
        COUNT(*) FILTER (WHERE m.status = 'pending') as pending_members,
        COUNT(*) FILTER (WHERE m.status = 'inactive') as inactive_members,
        COUNT(*) FILTER (WHERE m.status = 'suspended') as suspended_members,
        (SELECT COUNT(*) FROM mailing_lists WHERE association_id = assoc_id) as total_mailing_lists,
        (SELECT COUNT(*) FROM email_campaigns WHERE association_id = assoc_id) as total_campaigns,
        (SELECT COALESCE(SUM(recipient_count), 0) FROM email_campaigns WHERE association_id = assoc_id) as total_emails_sent
    FROM members m
    WHERE m.association_id = assoc_id;
END;
$$;

CREATE OR REPLACE FUNCTION get_mailing_list_subscriber_count(list_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    subscriber_count INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO subscriber_count
    FROM mailing_list_subscriptions
    WHERE mailing_list_id = list_id AND is_active = true;
    
    RETURN COALESCE(subscriber_count, 0);
END;
$$;

-- Subscription management functions
CREATE OR REPLACE FUNCTION subscribe_to_mailing_list(list_id UUID, member_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO mailing_list_subscriptions (mailing_list_id, member_id, is_active, subscribed_at)
    VALUES (list_id, member_id, true, NOW())
    ON CONFLICT (mailing_list_id, member_id)
    DO UPDATE SET 
        is_active = true,
        subscribed_at = NOW(),
        unsubscribed_at = NULL;
    
    RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION unsubscribe_from_mailing_list(list_id UUID, member_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE mailing_list_subscriptions
    SET is_active = false, unsubscribed_at = NOW()
    WHERE mailing_list_id = list_id AND member_id = member_id;
    
    RETURN true;
END;
$$;

-- Insert sample data
INSERT INTO associations (name, code, description, status) VALUES
    ('Default Association', 'DEFAULT', 'Initial association for system setup', 'active'),
    ('Sample Bell Ringers', 'SBR', 'Sample bell ringing association for demonstration', 'active')
ON CONFLICT (code) DO NOTHING;

-- Create sample mailing lists for the default association
INSERT INTO mailing_lists (association_id, name, description, type, auto_subscribe_new_members, status)
SELECT 
    a.id,
    'General Announcements',
    'Important announcements and updates for all members',
    'announcements',
    true,
    'active'
FROM associations a
WHERE a.code = 'DEFAULT'
ON CONFLICT (association_id, name) DO NOTHING;

INSERT INTO mailing_lists (association_id, name, description, type, auto_subscribe_new_members, status)
SELECT 
    a.id,
    'Monthly Newsletter',
    'Monthly newsletter with updates and news',
    'newsletter',
    false,
    'active'
FROM associations a
WHERE a.code = 'DEFAULT'
ON CONFLICT (association_id, name) DO NOTHING;

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO authenticated, anon;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;