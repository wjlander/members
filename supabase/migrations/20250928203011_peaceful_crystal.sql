/*
  # Rollback Migration Script

  This script provides rollback procedures for the PostgreSQL migration.
  Use with caution - this will remove all data and schema changes.
*/

-- Function to backup current data before rollback
CREATE OR REPLACE FUNCTION backup_before_rollback()
RETURNS VOID AS $$
DECLARE
    backup_timestamp VARCHAR(20);
BEGIN
    backup_timestamp := to_char(NOW(), 'YYYY_MM_DD_HH24_MI_SS');
    
    -- Create backup schema
    EXECUTE format('CREATE SCHEMA IF NOT EXISTS backup_%s', backup_timestamp);
    
    -- Backup all tables
    EXECUTE format('CREATE TABLE backup_%s.associations AS SELECT * FROM associations', backup_timestamp);
    EXECUTE format('CREATE TABLE backup_%s.users AS SELECT * FROM users', backup_timestamp);
    EXECUTE format('CREATE TABLE backup_%s.members AS SELECT * FROM members', backup_timestamp);
    EXECUTE format('CREATE TABLE backup_%s.member_payments AS SELECT * FROM member_payments', backup_timestamp);
    EXECUTE format('CREATE TABLE backup_%s.announcements AS SELECT * FROM announcements', backup_timestamp);
    EXECUTE format('CREATE TABLE backup_%s.mailing_lists AS SELECT * FROM mailing_lists', backup_timestamp);
    EXECUTE format('CREATE TABLE backup_%s.mailing_list_subscriptions AS SELECT * FROM mailing_list_subscriptions', backup_timestamp);
    EXECUTE format('CREATE TABLE backup_%s.email_campaigns AS SELECT * FROM email_campaigns', backup_timestamp);
    EXECUTE format('CREATE TABLE backup_%s.email_delivery_logs AS SELECT * FROM email_delivery_logs', backup_timestamp);
    
    RAISE NOTICE 'Backup created in schema: backup_%', backup_timestamp;
END;
$$ LANGUAGE plpgsql;

-- Function to perform complete rollback
CREATE OR REPLACE FUNCTION rollback_migration()
RETURNS VOID AS $$
BEGIN
    RAISE NOTICE 'Starting rollback process...';
    
    -- Create backup first
    PERFORM backup_before_rollback();
    
    -- Drop all tables in reverse dependency order
    DROP TABLE IF EXISTS email_delivery_logs CASCADE;
    DROP TABLE IF EXISTS email_campaigns CASCADE;
    DROP TABLE IF EXISTS mailing_list_subscriptions CASCADE;
    DROP TABLE IF EXISTS mailing_lists CASCADE;
    DROP TABLE IF EXISTS announcements CASCADE;
    DROP TABLE IF EXISTS member_payments CASCADE;
    DROP TABLE IF EXISTS members CASCADE;
    DROP TABLE IF EXISTS users CASCADE;
    DROP TABLE IF EXISTS associations CASCADE;
    
    -- Drop custom types
    DROP TYPE IF EXISTS user_role CASCADE;
    DROP TYPE IF EXISTS member_status CASCADE;
    DROP TYPE IF EXISTS membership_type CASCADE;
    DROP TYPE IF EXISTS payment_status CASCADE;
    DROP TYPE IF EXISTS payment_type CASCADE;
    DROP TYPE IF EXISTS payment_method CASCADE;
    DROP TYPE IF EXISTS association_status CASCADE;
    DROP TYPE IF EXISTS announcement_status CASCADE;
    DROP TYPE IF EXISTS mailing_list_type CASCADE;
    
    -- Drop functions
    DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;
    DROP FUNCTION IF EXISTS get_user_association_id() CASCADE;
    DROP FUNCTION IF EXISTS get_user_role() CASCADE;
    DROP FUNCTION IF EXISTS is_current_user(UUID) CASCADE;
    DROP FUNCTION IF EXISTS generate_member_id(VARCHAR) CASCADE;
    DROP FUNCTION IF EXISTS auto_generate_member_id() CASCADE;
    DROP FUNCTION IF EXISTS auto_subscribe_member() CASCADE;
    DROP FUNCTION IF EXISTS update_campaign_stats() CASCADE;
    DROP FUNCTION IF EXISTS validate_member_email() CASCADE;
    DROP FUNCTION IF EXISTS prevent_duplicate_subscriptions() CASCADE;
    DROP FUNCTION IF EXISTS get_association_stats(UUID) CASCADE;
    DROP FUNCTION IF EXISTS get_mailing_list_subscriber_count(UUID) CASCADE;
    DROP FUNCTION IF EXISTS unsubscribe_from_mailing_list(UUID, UUID) CASCADE;
    DROP FUNCTION IF EXISTS resubscribe_to_mailing_list(UUID, UUID) CASCADE;
    DROP FUNCTION IF EXISTS cleanup_old_email_logs() CASCADE;
    DROP FUNCTION IF EXISTS import_pocketbase_data() CASCADE;
    DROP FUNCTION IF EXISTS validate_migration() CASCADE;
    DROP FUNCTION IF EXISTS backup_before_rollback() CASCADE;
    
    -- Drop extensions (only if not used by other applications)
    -- DROP EXTENSION IF EXISTS "uuid-ossp";
    -- DROP EXTENSION IF EXISTS "pgcrypto";
    
    RAISE NOTICE 'Rollback completed successfully';
    RAISE NOTICE 'Data has been backed up in backup_* schemas';
END;
$$ LANGUAGE plpgsql;

-- Partial rollback functions for specific components

-- Rollback only email-related tables
CREATE OR REPLACE FUNCTION rollback_email_features()
RETURNS VOID AS $$
BEGIN
    DROP TABLE IF EXISTS email_delivery_logs CASCADE;
    DROP TABLE IF EXISTS email_campaigns CASCADE;
    RAISE NOTICE 'Email features rolled back';
END;
$$ LANGUAGE plpgsql;

-- Rollback only mailing list features
CREATE OR REPLACE FUNCTION rollback_mailing_lists()
RETURNS VOID AS $$
BEGIN
    DROP TABLE IF EXISTS mailing_list_subscriptions CASCADE;
    DROP TABLE IF EXISTS mailing_lists CASCADE;
    DROP TYPE IF EXISTS mailing_list_type CASCADE;
    RAISE NOTICE 'Mailing list features rolled back';
END;
$$ LANGUAGE plpgsql;

-- Function to restore from backup
CREATE OR REPLACE FUNCTION restore_from_backup(backup_schema_name VARCHAR)
RETURNS VOID AS $$
BEGIN
    -- This is a template - implement based on your backup strategy
    RAISE NOTICE 'Restoring from backup schema: %', backup_schema_name;
    
    -- Example restore commands (customize based on your needs)
    EXECUTE format('INSERT INTO associations SELECT * FROM %I.associations', backup_schema_name);
    EXECUTE format('INSERT INTO users SELECT * FROM %I.users', backup_schema_name);
    -- Add more restore commands as needed
    
    RAISE NOTICE 'Restore completed from schema: %', backup_schema_name;
END;
$$ LANGUAGE plpgsql;

-- Usage examples:
-- SELECT backup_before_rollback();  -- Create backup
-- SELECT rollback_migration();      -- Full rollback
-- SELECT rollback_email_features(); -- Partial rollback
-- SELECT restore_from_backup('backup_2024_01_15_10_30_00'); -- Restore from backup