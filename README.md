# Member Management System

A comprehensive multi-tenant member management system built with PocketBase and Alpine.js, designed for cost-effective deployment and operation.

## System Architecture

### Technology Stack
- **Backend**: PocketBase (Go-based, single binary, embedded database)
- **Frontend**: Alpine.js + Tailwind CSS (lightweight, CDN-based)
- **Database**: SQLite (embedded with PocketBase)
- **Server**: Debian-based Linux server
- **Reverse Proxy**: Nginx
- **Process Manager**: systemd

### Architecture Benefits
- **Cost-effective**: No external database costs, minimal server requirements
- **Simple deployment**: Single binary backend with embedded database
- **Low maintenance**: Self-contained system with automatic backups
- **Scalable**: Supports multiple associations with data isolation

## Features

### Member Features
- Registration with association selection
- Profile management
- Membership status tracking
- Dues payment history
- Document uploads

### Admin Features
- Member approval workflow
- Bulk operations (import/export)
- Reporting and analytics
- Association settings management
- Member communication tools

## Minimum Server Requirements
- **OS**: Debian 11+ or Ubuntu 20.04+
- **CPU**: 1 vCPU
- **RAM**: 512 MB (1GB recommended)
- **Storage**: 10GB (20GB recommended)
- **Network**: Public IP with port 80/443 access

## Quick Deployment

1. Download and run the deployment script:
```bash
curl -sSL https://raw.githubusercontent.com/your-repo/member-management/main/deploy.sh | sudo bash
```

2. Access the main system at `https://member.ringing.org.uk/`

3. Access the admin panel at `https://p.ringing.org.uk/_/`

4. Configure your first association

## Cost Breakdown (Monthly)

| Component | Cost | Notes |
|-----------|------|--------|
| VPS Server (1GB RAM) | $5-10 | DigitalOcean, Vultr, Linode |
| Domain | $1-2 | Annual cost divided by 12 |
| SSL Certificate | $0 | Let's Encrypt (free) |
| **Total** | **$6-12** | Scales with server size |

## Documentation Contents

- [Deployment Guide](docs/DEPLOYMENT.md)
- [User Manual](docs/USER_MANUAL.md)
- [Admin Guide](docs/ADMIN_GUIDE.md)
- [API Documentation](docs/API.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Backup & Recovery](docs/BACKUP.md)
- [Security Guide](docs/SECURITY.md)

## Support

For technical support or feature requests, please refer to the documentation or contact your system administrator.