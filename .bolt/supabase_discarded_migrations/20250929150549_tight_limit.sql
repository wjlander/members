/*
  # Fixed Initial PostgreSQL Schema Migration

  This file fixes the type casting issues in the original migration
  and creates all necessary tables for the Member Management System.
*/

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Create custom types
CREATE TYPE user_role AS ENUM ('super_admin', 'admin', 'member');
CREATE TYPE member_status AS ENUM ('pending', 'active', 'inactive', 'suspended');
CREATE TYPE membership_type AS ENUM ('regular', 'premium', 'student', 'senior', 'honorary');
CREATE TYPE payment_status AS ENUM ('pending', 'paid', 'overdue', 'waived');
CREATE TYPE payment_type AS ENUM ('monthly', 'quarterly', 'annual', 'registration', 'special');
CREATE TYPE payment_method AS ENUM ('cash', 'check', 'card', 'bank_transfer', 'paypal', 'other');
CREATE TYPE association_status AS ENUM ('active', 'inactive');
CREATE TYPE announcement_status AS ENUM ('draft', 'published', 'archived');
CREATE TYPE mailing_list_type AS ENUM ('general', 'announcements', 'events', 'newsletter', 'urgent', 'social');

-- Associations table
CREATE TABLE associations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    code VARCHAR(10) NOT NULL UNIQUE,
    description TEXT,
    settings JSONB DEFAULT '{}',
    status association_status NOT NULL DEFAULT 'active',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index for associations
CREATE INDEX idx_associations_code ON associations(code);
CREATE INDEX idx_associations_status ON associations(status);

-- Users table (authentication)
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    name VARCHAR(255) NOT NULL,
    role user_role NOT NULL DEFAULT 'member',
    association_id UUID REFERENCES associations(id) ON DELETE SET NULL,
    avatar_url VARCHAR(500),
    email_verified BOOLEAN DEFAULT FALSE,
    last_login TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for users
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_association ON users(association_id);
CREATE INDEX idx_users_role ON users(role);

-- Members table
CREATE TABLE members (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    association_id UUID NOT NULL REFERENCES associations(id) ON DELETE CASCADE,
    member_id VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    phone VARCHAR(20),
    address TEXT,
    date_of_birth DATE,
    status member_status NOT NULL DEFAULT 'pending',
    membership_type membership_type DEFAULT 'regular',
    join_date DATE DEFAULT CURRENT_DATE,
    notes TEXT,
    documents JSONB DEFAULT '[]',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, association_id)
);

-- Create indexes for members
CREATE INDEX idx_members_user ON members(user_id);
CREATE INDEX idx_members_association ON members(association_id);
CREATE INDEX idx_members_member_id ON members(member_id);
CREATE INDEX idx_members_status ON members(status);
CREATE INDEX idx_members_email ON members(email);

-- Member payments table
CREATE TABLE member_payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
    association_id UUID NOT NULL REFERENCES associations(id) ON DELETE CASCADE,
    type payment_type NOT NULL,
    amount DECIMAL(10,2) NOT NULL CHECK (amount >= 0),
    due_date DATE NOT NULL,
    paid_date DATE,
    status payment_status NOT NULL DEFAULT 'pending',
    payment_method payment_method,
    reference_number VARCHAR(100),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for member_payments
CREATE INDEX idx_payments_member ON member_payments(member_id);
CREATE INDEX idx_payments_association ON member_payments(association_id);
CREATE INDEX idx_payments_status ON member_payments(status);
CREATE INDEX idx_payments_due_date ON member_payments(due_date);
CREATE INDEX idx_payments_type ON member_payments(type);

-- Announcements table (FIXED: proper target_roles column)
CREATE TABLE announcements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    association_id UUID NOT NULL REFERENCES associations(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    author_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status announcement_status NOT NULL DEFAULT 'draft',
    published_at TIMESTAMP WITH TIME ZONE,
    expires_at TIMESTAMP WITH TIME ZONE,
    target_roles TEXT[] DEFAULT ARRAY['member']::TEXT[],
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for announcements
CREATE INDEX idx_announcements_association ON announcements(association_id);
CREATE INDEX idx_announcements_status ON announcements(status);
CREATE INDEX idx_announcements_published ON announcements(published_at);

-- Mailing lists table
CREATE TABLE mailing_lists (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    association_id UUID NOT NULL REFERENCES associations(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    type mailing_list_type NOT NULL DEFAULT 'general',
    moderator_email VARCHAR(255),
    auto_subscribe_new_members BOOLEAN DEFAULT FALSE,
    status association_status NOT NULL DEFAULT 'active',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(association_id, name)
);

-- Create indexes for mailing_lists
CREATE INDEX idx_mailing_lists_association ON mailing_lists(association_id);
CREATE INDEX idx_mailing_lists_type ON mailing_lists(type);
CREATE INDEX idx_mailing_lists_status ON mailing_lists(status);

-- Mailing list subscriptions table
CREATE TABLE mailing_list_subscriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    mailing_list_id UUID NOT NULL REFERENCES mailing_lists(id) ON DELETE CASCADE,
    member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
    subscribed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    unsubscribed_at TIMESTAMP WITH TIME ZONE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(mailing_list_id, member_id)
);

-- Create indexes for mailing_list_subscriptions
CREATE INDEX idx_subscriptions_list ON mailing_list_subscriptions(mailing_list_id);
CREATE INDEX idx_subscriptions_member ON mailing_list_subscriptions(member_id);
CREATE INDEX idx_subscriptions_active ON mailing_list_subscriptions(is_active);

-- Email campaigns table (for Resend integration)
CREATE TABLE email_campaigns (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    association_id UUID NOT NULL REFERENCES associations(id) ON DELETE CASCADE,
    mailing_list_id UUID REFERENCES mailing_lists(id) ON DELETE SET NULL,
    sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    subject VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    template_name VARCHAR(100),
    scheduled_at TIMESTAMP WITH TIME ZONE,
    sent_at TIMESTAMP WITH TIME ZONE,
    status VARCHAR(50) DEFAULT 'draft',
    recipient_count INTEGER DEFAULT 0,
    delivered_count INTEGER DEFAULT 0,
    opened_count INTEGER DEFAULT 0,
    clicked_count INTEGER DEFAULT 0,
    bounced_count INTEGER DEFAULT 0,
    resend_campaign_id VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for email_campaigns
CREATE INDEX idx_campaigns_association ON email_campaigns(association_id);
CREATE INDEX idx_campaigns_list ON email_campaigns(mailing_list_id);
CREATE INDEX idx_campaigns_status ON email_campaigns(status);
CREATE INDEX idx_campaigns_scheduled ON email_campaigns(scheduled_at);

-- Email delivery logs table
CREATE TABLE email_delivery_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    campaign_id UUID REFERENCES email_campaigns(id) ON DELETE CASCADE,
    member_id UUID REFERENCES members(id) ON DELETE CASCADE,
    email VARCHAR(255) NOT NULL,
    status VARCHAR(50) NOT NULL,
    resend_message_id VARCHAR(255),
    delivered_at TIMESTAMP WITH TIME ZONE,
    opened_at TIMESTAMP WITH TIME ZONE,
    clicked_at TIMESTAMP WITH TIME ZONE,
    bounced_at TIMESTAMP WITH TIME ZONE,
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for email_delivery_logs
CREATE INDEX idx_delivery_logs_campaign ON email_delivery_logs(campaign_id);
CREATE INDEX idx_delivery_logs_member ON email_delivery_logs(member_id);
CREATE INDEX idx_delivery_logs_status ON email_delivery_logs(status);
CREATE INDEX idx_delivery_logs_email ON email_delivery_logs(email);

-- Create updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply updated_at triggers to all tables
CREATE TRIGGER update_associations_updated_at BEFORE UPDATE ON associations FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_members_updated_at BEFORE UPDATE ON members FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_member_payments_updated_at BEFORE UPDATE ON member_payments FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_announcements_updated_at BEFORE UPDATE ON announcements FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_mailing_lists_updated_at BEFORE UPDATE ON mailing_lists FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_mailing_list_subscriptions_updated_at BEFORE UPDATE ON mailing_list_subscriptions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_email_campaigns_updated_at BEFORE UPDATE ON email_campaigns FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_email_delivery_logs_updated_at BEFORE UPDATE ON email_delivery_logs FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Enable Row Level Security
ALTER TABLE associations ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE members ENABLE ROW LEVEL SECURITY;
ALTER TABLE member_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE mailing_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE mailing_list_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_delivery_logs ENABLE ROW LEVEL SECURITY;