# PostgreSQL Migration Guide

This guide covers the complete migration from PocketBase to PostgreSQL for the Member Management System.

## Table of Contents

1. [Migration Overview](#migration-overview)
2. [Prerequisites](#prerequisites)
3. [Database Schema](#database-schema)
4. [Data Migration](#data-migration)
5. [Application Updates](#application-updates)
6. [Deployment](#deployment)
7. [Rollback Procedures](#rollback-procedures)
8. [Performance Optimization](#performance-optimization)

## Migration Overview

### What's Changed

- **Database**: SQLite (PocketBase) → PostgreSQL 15+
- **Backend**: PocketBase → Node.js/Express
- **Authentication**: PocketBase Auth → JWT with bcrypt
- **Email**: Built-in → Resend API integration
- **File Storage**: PocketBase → Local filesystem with Multer
- **Security**: PocketBase RLS → Custom middleware + PostgreSQL RLS

### Benefits of Migration

1. **Scalability**: PostgreSQL handles larger datasets and concurrent users better
2. **Performance**: Better query optimization and indexing capabilities
3. **Flexibility**: Custom business logic and integrations
4. **Email Integration**: Professional email service with tracking
5. **Monitoring**: Better logging and monitoring capabilities
6. **Backup**: More robust backup and recovery options

## Prerequisites

### System Requirements

- **OS**: Debian 11+ or Ubuntu 20.04+
- **RAM**: 2GB minimum (4GB recommended)
- **Storage**: 20GB minimum (50GB recommended)
- **PostgreSQL**: Version 15 or higher
- **Node.js**: Version 18 or higher

### Required Services

- PostgreSQL server
- Nginx (reverse proxy)
- SSL certificates (Let's Encrypt)
- Resend account (for email features)

## Database Schema

### Core Tables

The new PostgreSQL schema includes:

```sql
-- Core entities
associations        -- Organization/association management
users              -- Authentication and user management  
members            -- Member profiles and data
member_payments    -- Dues and payment tracking

-- Communication
announcements      -- System announcements
mailing_lists      -- Email list management
mailing_list_subscriptions -- List subscriptions

-- Email system
email_campaigns    -- Email campaign management
email_delivery_logs -- Email tracking and analytics
```

### Key Features

1. **UUID Primary Keys**: Enhanced security and distributed system support
2. **Row Level Security**: Data isolation between associations
3. **Audit Trails**: Created/updated timestamps on all tables
4. **Proper Indexing**: Optimized for common query patterns
5. **Foreign Key Constraints**: Data integrity enforcement
6. **Custom Types**: Enums for status fields and categories

### Schema Migration

Run the schema migration scripts in order:

```bash
# 1. Create initial schema
psql -d member_management -f database/postgresql/schema/001_initial_schema.sql

# 2. Setup Row Level Security policies
psql -d member_management -f database/postgresql/schema/002_rls_policies.sql

# 3. Create functions and triggers
psql -d member_management -f database/postgresql/schema/003_functions_and_triggers.sql
```

## Data Migration

### Automated Migration

The deployment script includes automated migration:

```bash
sudo ./deploy-postgresql.sh
```

### Manual Migration Steps

If you need to migrate existing PocketBase data:

1. **Export PocketBase Data**:
   ```bash
   # Access PocketBase admin panel
   # Go to Settings > Import/Export
   # Export all collections as JSON
   ```

2. **Prepare Migration Script**:
   ```bash
   # Edit database/postgresql/migrations/migrate_from_pocketbase.sql
   # Add your exported data
   ```

3. **Run Migration**:
   ```bash
   psql -d member_management -f database/postgresql/migrations/migrate_from_pocketbase.sql
   ```

### Data Mapping

| PocketBase Collection | PostgreSQL Table | Notes |
|----------------------|-------------------|-------|
| `ringing_associations` | `associations` | Direct mapping |
| `member_users` | `users` | Password hashing required |
| `ringing_members` | `members` | User relationship updated |
| `member_payments` | `member_payments` | Direct mapping |
| `ringing_announcements` | `announcements` | Direct mapping |
| `ringing_mailing_lists` | `mailing_lists` | Direct mapping |
| `ringing_subscriptions` | `mailing_list_subscriptions` | Direct mapping |

## Application Updates

### Backend Changes

1. **New Node.js/Express Server**:
   - RESTful API endpoints
   - JWT authentication
   - PostgreSQL integration
   - Resend email service

2. **Security Enhancements**:
   - Helmet.js for security headers
   - Rate limiting
   - CORS configuration
   - Input validation with Joi

3. **Logging and Monitoring**:
   - Winston logger
   - Structured logging
   - Error tracking
   - Performance monitoring

### Frontend Updates

The frontend remains largely unchanged but with updated API endpoints:

```javascript
// Old PocketBase calls
pb.collection('ringing_associations').getFullList()

// New REST API calls  
fetch('/api/associations')
```

### Configuration

Update environment variables in `.env`:

```bash
# Database
DB_HOST=localhost
DB_NAME=member_management
DB_USER=memberapp_user
DB_PASSWORD=your_password

# Email (Resend)
RESEND_API_KEY=your_resend_key
FROM_EMAIL=noreply@yourdomain.com

# Security
JWT_SECRET=your_jwt_secret
BCRYPT_ROUNDS=12
```

## Deployment

### Automated Deployment

Use the provided deployment script:

```bash
# Download and run
curl -sSL https://raw.githubusercontent.com/your-repo/member-management/main/deploy-postgresql.sh | sudo bash

# Or download first
wget https://raw.githubusercontent.com/your-repo/member-management/main/deploy-postgresql.sh
chmod +x deploy-postgresql.sh
sudo ./deploy-postgresql.sh
```

### Manual Deployment

1. **Install Dependencies**:
   ```bash
   sudo apt update
   sudo apt install postgresql-15 nodejs npm nginx
   ```

2. **Setup Database**:
   ```bash
   sudo -u postgres createdb member_management
   sudo -u postgres createuser memberapp_user
   ```

3. **Deploy Application**:
   ```bash
   cd /opt/member-management
   npm install
   npm start
   ```

4. **Configure Nginx**:
   ```bash
   sudo cp config/nginx.conf /etc/nginx/sites-available/member-management
   sudo ln -s /etc/nginx/sites-available/member-management /etc/nginx/sites-enabled/
   sudo systemctl reload nginx
   ```

### Health Checks

Verify the deployment:

```bash
# Check PostgreSQL
sudo -u postgres psql -d member_management -c "SELECT version();"

# Check application
curl http://localhost:3000/health

# Check Nginx
curl -I http://your-domain.com
```

## Rollback Procedures

### Database Rollback

If you need to rollback the database migration:

```bash
# Create backup first
sudo -u postgres pg_dump member_management > backup_before_rollback.sql

# Run rollback script
psql -d member_management -f database/postgresql/rollback/rollback_migration.sql
```

### Application Rollback

To rollback to PocketBase:

1. **Stop New Services**:
   ```bash
   sudo systemctl stop member-management
   sudo systemctl disable member-management
   ```

2. **Restore PocketBase**:
   ```bash
   # Restore PocketBase binary and data
   sudo systemctl start pocketbase
   ```

3. **Update Nginx**:
   ```bash
   # Restore PocketBase Nginx configuration
   sudo systemctl reload nginx
   ```

### Data Recovery

If you need to recover data:

```bash
# Restore from PostgreSQL backup
sudo -u postgres psql -d member_management < backup_file.sql

# Or restore from PocketBase backup
cd /var/lib/pocketbase
sudo tar -xzf backups/pocketbase_backup_YYYYMMDD.tar.gz
```

## Performance Optimization

### Database Optimization

1. **Connection Pooling**:
   ```javascript
   // Already configured in backend/config/database.js
   const pool = new Pool({
       max: 20,
       idleTimeoutMillis: 30000,
       connectionTimeoutMillis: 2000
   });
   ```

2. **Query Optimization**:
   ```sql
   -- Analyze query performance
   EXPLAIN ANALYZE SELECT * FROM members WHERE association_id = $1;
   
   -- Update table statistics
   ANALYZE members;
   ```

3. **Index Monitoring**:
   ```sql
   -- Check index usage
   SELECT schemaname, tablename, attname, n_distinct, correlation 
   FROM pg_stats WHERE tablename = 'members';
   ```

### Application Optimization

1. **Caching**: Implement Redis for session storage and caching
2. **Rate Limiting**: Configure appropriate limits for your usage
3. **Compression**: Enable gzip compression in Nginx
4. **CDN**: Use CDN for static assets

### Monitoring

1. **Database Monitoring**:
   ```sql
   -- Monitor active connections
   SELECT count(*) FROM pg_stat_activity;
   
   -- Check slow queries
   SELECT query, mean_time, calls 
   FROM pg_stat_statements 
   ORDER BY mean_time DESC LIMIT 10;
   ```

2. **Application Monitoring**:
   ```bash
   # Check application logs
   sudo journalctl -u member-management -f
   
   # Monitor system resources
   htop
   ```

### Backup Strategy

1. **Automated Backups**:
   ```bash
   # Daily database backup (already configured)
   /usr/local/bin/backup-member-management
   ```

2. **Backup Verification**:
   ```bash
   # Test backup restoration
   sudo -u postgres pg_restore --list backup_file.sql
   ```

3. **Offsite Backups**:
   ```bash
   # Sync to cloud storage (example with AWS S3)
   aws s3 sync /var/lib/member-management/backups/ s3://your-backup-bucket/
   ```

## Troubleshooting

### Common Issues

1. **Connection Issues**:
   ```bash
   # Check PostgreSQL status
   sudo systemctl status postgresql
   
   # Check connection
   sudo -u postgres psql -d member_management -c "SELECT 1;"
   ```

2. **Permission Issues**:
   ```bash
   # Fix file permissions
   sudo chown -R memberapp:memberapp /var/lib/member-management
   
   # Check database permissions
   sudo -u postgres psql -d member_management -c "\dp"
   ```

3. **Performance Issues**:
   ```sql
   -- Check for locks
   SELECT * FROM pg_locks WHERE NOT granted;
   
   -- Check connection count
   SELECT count(*) FROM pg_stat_activity;
   ```

### Getting Help

1. **Logs**: Check application and database logs
2. **Documentation**: Review PostgreSQL and Node.js documentation
3. **Community**: PostgreSQL and Node.js communities
4. **Support**: Contact your system administrator

## Migration Checklist

- [ ] Backup existing PocketBase data
- [ ] Install PostgreSQL and dependencies
- [ ] Run database schema migration
- [ ] Migrate data from PocketBase
- [ ] Deploy Node.js application
- [ ] Configure Nginx and SSL
- [ ] Test all functionality
- [ ] Setup monitoring and backups
- [ ] Update DNS if needed
- [ ] Train users on any changes
- [ ] Document any customizations

## Post-Migration Tasks

1. **Performance Tuning**: Monitor and optimize queries
2. **Security Review**: Audit permissions and access controls
3. **Backup Testing**: Verify backup and restore procedures
4. **User Training**: Update documentation and train users
5. **Monitoring Setup**: Configure alerts and monitoring
6. **Maintenance Schedule**: Plan regular maintenance tasks

The migration to PostgreSQL provides a more robust, scalable foundation for your member management system with enhanced email capabilities and better performance characteristics.