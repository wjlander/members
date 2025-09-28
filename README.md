# Member Management System

A comprehensive multi-tenant member management system built with PostgreSQL, Node.js, and Alpine.js, featuring professional email integration with Resend.

## System Architecture

### Technology Stack
- **Backend**: Node.js/Express with PostgreSQL
- **Frontend**: Alpine.js + Tailwind CSS (lightweight, CDN-based)
- **Database**: PostgreSQL 15+ with Row Level Security
- **Email**: Resend API integration for professional email delivery
- **Server**: Debian-based Linux server
- **Reverse Proxy**: Nginx
- **Process Manager**: systemd

### Architecture Benefits
- **Scalable**: PostgreSQL handles large datasets and concurrent users
- **Professional Email**: Resend integration with tracking and analytics
- **Robust**: Enterprise-grade database with ACID compliance
- **Flexible**: Custom business logic and API integrations
- **Scalable**: Supports multiple associations with data isolation

## Features

### Member Features
- Registration with association selection
- Profile management
- Membership status tracking
- Dues payment history
- Document uploads
- Email notifications and communications

### Admin Features
- Member approval workflow
- Bulk operations (import/export)
- Reporting and analytics
- Association settings management
- Email campaign management
- Mailing list administration
- Email analytics and tracking

### Email Features
- Professional email delivery via Resend
- Bulk email campaigns
- Mailing list management
- Email templates and personalization
- Real-time delivery tracking
- Open and click analytics
- Bounce and complaint handling
## Minimum Server Requirements
- **OS**: Debian 11+ or Ubuntu 20.04+
- **CPU**: 1 vCPU
- **RAM**: 2GB (4GB recommended)
- **Storage**: 20GB (50GB recommended)
- **Network**: Public IP with port 80/443 access

## Quick Deployment

1. Download and run the deployment script:
```bash
curl -sSL https://raw.githubusercontent.com/your-repo/member-management/main/deploy-postgresql.sh | sudo bash
```

2. Configure your domains and Resend API key during installation

3. Access the main system at `https://your-domain.com/`

4. Access the admin panel at `https://admin.your-domain.com/`

5. Complete initial setup and create your first association
## Cost Breakdown (Monthly)

| Component | Cost | Notes |
|-----------|------|--------|
- VPS Server (2GB RAM) | $10-20 | DigitalOcean, Vultr, Linode |
| Domain | $1-2 | Annual cost divided by 12 |
| SSL Certificate | $0 | Let's Encrypt (free) |
- Resend Email | $0-20 | Free tier: 3,000 emails/month |
- **Total** | **$11-42** | Scales with usage |

## Documentation Contents

- [Deployment Guide](docs/DEPLOYMENT.md)
- [PostgreSQL Migration Guide](docs/POSTGRESQL_MIGRATION.md)
- [Resend Email Integration](docs/RESEND_INTEGRATION.md)
- [User Manual](docs/USER_MANUAL.md)
- [Admin Guide](docs/ADMIN_GUIDE.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Backup & Recovery](docs/BACKUP.md)
- [Security Guide](docs/SECURITY.md)

## Migration from PocketBase

If you're upgrading from the PocketBase version:

1. **Backup your data**: Export all data from PocketBase admin panel
2. **Run migration**: Use the PostgreSQL deployment script
3. **Import data**: Follow the migration guide for data transfer
4. **Test thoroughly**: Verify all functionality works correctly
5. **Update DNS**: Point domains to new server when ready

See [PostgreSQL Migration Guide](docs/POSTGRESQL_MIGRATION.md) for detailed instructions.

## Email Integration

The system includes professional email capabilities:

- **Transactional Emails**: Welcome, approval, password reset
- **Marketing Campaigns**: Newsletters, announcements, events
- **Mailing Lists**: Segmented communication groups
- **Analytics**: Open rates, click tracking, delivery reports
- **Templates**: Professional, responsive email templates

See [Resend Integration Guide](docs/RESEND_INTEGRATION.md) for setup instructions.

## Support

For technical support or feature requests, please refer to the documentation or contact your system administrator.