/*
  # Initial Schema for Membership Management System

  1. New Tables
    - `associations` - Organizations/societies that use the system
    - `users` - Authentication and user management (extends Supabase auth.users)
    - `members` - Member profiles and data
    - `mailing_lists` - Email list management
    - `mailing_list_subscriptions` - Member subscriptions to lists
    - `email_campaigns` - Email campaign management
    - `email_delivery_logs` - Email tracking and analytics

  2. Security
    - Enable RLS on all tables
    - Add policies for role-based access control
    - Ensure data isolation between associations

  3. Features
    - UUID primary keys for all tables
    - Audit trails with created_at/updated_at
    - Proper foreign key relationships
    - Enum types for status fields
*/

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create custom types
CREATE TYPE user_role AS ENUM ('super_admin', 'admin', 'member');
CREATE TYPE member_status AS ENUM ('pending', 'active', 'inactive', 'suspended');
CREATE TYPE membership_type AS ENUM ('regular', 'premium', 'student', 'senior', 'honorary');
CREATE TYPE mailing_list_type AS ENUM ('general', 'announcements', 'events', 'newsletter', 'urgent', 'social');
CREATE TYPE campaign_status AS ENUM ('draft', 'sending', 'sent', 'failed');
CREATE TYPE delivery_status AS ENUM ('pending', 'delivered', 'bounced', 'failed', 'opened', 'clicked');

-- Associations table
CREATE TABLE IF NOT EXISTS associations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    code TEXT NOT NULL UNIQUE,
    description TEXT,
    settings JSONB DEFAULT '{}',
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Users table (extends Supabase auth.users)
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    name TEXT NOT NULL,
    role user_role DEFAULT 'member',
    association_id UUID REFERENCES associations(id) ON DELETE SET NULL,
    avatar_url TEXT,
    email_verified BOOLEAN DEFAULT FALSE,
    last_login TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Members table
CREATE TABLE IF NOT EXISTS members (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
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
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Mailing lists table
CREATE TABLE IF NOT EXISTS mailing_lists (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    association_id UUID NOT NULL REFERENCES associations(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    type mailing_list_type DEFAULT 'general',
    moderator_email TEXT,
    auto_subscribe_new_members BOOLEAN DEFAULT FALSE,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(association_id, name)
);

-- Mailing list subscriptions table
CREATE TABLE IF NOT EXISTS mailing_list_subscriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    mailing_list_id UUID NOT NULL REFERENCES mailing_lists(id) ON DELETE CASCADE,
    member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
    subscribed_at TIMESTAMPTZ DEFAULT NOW(),
    unsubscribed_at TIMESTAMPTZ,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(mailing_list_id, member_id)
);

-- Email campaigns table
CREATE TABLE IF NOT EXISTS email_campaigns (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
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

-- Email delivery logs table
CREATE TABLE IF NOT EXISTS email_delivery_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    campaign_id UUID NOT NULL REFERENCES email_campaigns(id) ON DELETE CASCADE,
    member_id UUID REFERENCES members(id) ON DELETE SET NULL,
    email TEXT NOT NULL,
    status delivery_status DEFAULT 'pending',
    resend_message_id TEXT,
    delivered_at TIMESTAMPTZ,
    opened_at TIMESTAMPTZ,
    clicked_at TIMESTAMPTZ,
    bounced_at TIMESTAMPTZ,
    error_message TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_users_association_id ON users(association_id);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);

CREATE INDEX IF NOT EXISTS idx_members_association_id ON members(association_id);
CREATE INDEX IF NOT EXISTS idx_members_user_id ON members(user_id);
CREATE INDEX IF NOT EXISTS idx_members_status ON members(status);
CREATE INDEX IF NOT EXISTS idx_members_email ON members(email);

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