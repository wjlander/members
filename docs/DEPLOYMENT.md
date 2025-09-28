# Deployment Guide

This guide will help you deploy the Member Management System on a Debian server.

## Prerequisites

- Debian 11+ or Ubuntu 20.04+ server
- Root or sudo access
- Domain name pointing to your server
- Minimum 512MB RAM (1GB recommended)
- 10GB storage space (20GB recommended)

## Automated Deployment

### Option 1: One-Line Installation

```bash
curl -sSL https://raw.githubusercontent.com/your-repo/member-management/main/deploy.sh | sudo bash
```

### Option 2: Download and Run

```bash
wget https://raw.githubusercontent.com/your-repo/member-management/main/deploy.sh
chmod +x deploy.sh
sudo ./deploy.sh
```

## Manual Deployment Steps

If you prefer to deploy manually or need to customize the installation:

### 1. System Preparation

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install dependencies
sudo apt install -y curl wget unzip nginx certbot python3-certbot-nginx ufw fail2ban
```

### 2. Create Application User

```bash
sudo useradd --system --shell /bin/false --home-dir /var/lib/pocketbase --create-home pocketbase
sudo mkdir -p /opt/member-management
sudo mkdir -p /var/log/pocketbase
```

### 3. Download and Install PocketBase

```bash
cd /tmp
wget https://github.com/pocketbase/pocketbase/releases/download/v0.20.1/pocketbase_0.20.1_linux_amd64.zip
unzip pocketbase_0.20.1_linux_amd64.zip
sudo mv pocketbase /opt/member-management/
sudo chmod +x /opt/member-management/pocketbase
sudo chown pocketbase:pocketbase /opt/member-management/pocketbase
```

### 4. Create Systemd Service

Create `/etc/systemd/system/pocketbase.service`:

```ini
[Unit]
Description=PocketBase Member Management System
After=network.target
Wants=network.target

[Service]
Type=simple
User=pocketbase
Group=pocketbase
ExecStart=/opt/member-management/pocketbase serve --http=127.0.0.1:8080 --dir=/var/lib/pocketbase
Restart=always
RestartSec=5
StandardOutput=append:/var/log/pocketbase/pocketbase.log
StandardError=append:/var/log/pocketbase/pocketbase-error.log

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/lib/pocketbase /var/log/pocketbase

[Install]
WantedBy=multi-user.target
```

Enable and start the service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable pocketbase
sudo systemctl start pocketbase
```

### 5. Configure Nginx

Create `/etc/nginx/sites-available/member-management`:

```nginx
server {
    listen 80;
    server_name member.ringing.org.uk;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    
    # File upload size limit
    client_max_body_size 100M;
    
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_cache_bypass $http_upgrade;
    }
    
    # Serve static files from PocketBase
    location /api/files/ {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Enable the site:

```bash
sudo ln -sf /etc/nginx/sites-available/member-management /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### 6. Setup SSL Certificate

```bash
sudo certbot --nginx -d member.ringing.org.uk -d p.ringing.org.uk
```

### 7. Configure Firewall

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 'Nginx Full'
sudo ufw --force enable
```

### 8. Setup Backup Script

Create `/usr/local/bin/backup-pocketbase`:

```bash
#!/bin/bash
BACKUP_DIR="/var/lib/pocketbase/backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/pocketbase_backup_$DATE.tar.gz"

mkdir -p "$BACKUP_DIR"
tar -czf "$BACKUP_FILE" -C /var/lib/pocketbase pb_data pb_migrations

# Keep only last 7 backups
cd "$BACKUP_DIR"
ls -t pocketbase_backup_*.tar.gz | tail -n +8 | xargs rm -f

echo "Backup created: $BACKUP_FILE"
```

Make it executable and setup cron:

```bash
sudo chmod +x /usr/local/bin/backup-pocketbase
sudo crontab -e
```

Add to crontab:
```bash
0 2 * * * /usr/local/bin/backup-pocketbase >> /var/log/pocketbase/backup.log 2>&1
```

## Initial Setup

1. Access the main system: `https://member.ringing.org.uk/`
2. Access the admin panel: `https://p.ringing.org.uk/_/`
3. Create your first admin user
4. Import the database schema from `pocketbase/pb_schema.json`
5. Create your first association
6. Configure system settings

## Verification

Check that everything is working:

```bash
# Check service status
sudo systemctl status pocketbase

# Check logs
sudo journalctl -u pocketbase -f

# Check Nginx
sudo nginx -t
sudo systemctl status nginx

# Test the application
curl -I https://member.ringing.org.uk
curl -I https://p.ringing.org.uk
```

## Post-Installation Tasks

1. **Create Super Admin**: Access the admin panel and create a super admin user
2. **Import Schema**: Import the provided database schema
3. **Create Associations**: Set up your associations/societies
4. **Configure Settings**: Customize membership types, dues, etc.
5. **Test Registration**: Test the member registration process
6. **Setup Monitoring**: Consider setting up monitoring and alerting

## Troubleshooting

### Service Won't Start

```bash
# Check logs
sudo journalctl -u pocketbase --no-pager -l

# Check file permissions
sudo ls -la /opt/member-management/
sudo ls -la /var/lib/pocketbase/

# Restart service
sudo systemctl restart pocketbase
```

### Nginx Issues

```bash
# Test configuration
sudo nginx -t

# Check Nginx logs
sudo tail -f /var/log/nginx/error.log

# Restart Nginx
sudo systemctl restart nginx
```

### SSL Certificate Issues

```bash
# Manual SSL setup if auto-setup failed
sudo certbot --nginx -d member.ringing.org.uk -d p.ringing.org.uk
```

### Database Issues

```bash
# Check data directory
sudo ls -la /var/lib/pocketbase/

# Restore from backup
sudo systemctl stop pocketbase
cd /var/lib/pocketbase
sudo tar -xzf backups/pocketbase_backup_YYYYMMDD_HHMMSS.tar.gz
sudo systemctl start pocketbase
```

## Security Considerations

1. **Regular Updates**: Keep PocketBase and system packages updated
2. **Backup Strategy**: Implement and test regular backups
3. **Access Control**: Use strong passwords and consider 2FA
4. **Monitoring**: Set up log monitoring and alerting
5. **Firewall**: Regularly review and update firewall rules

## Support

For additional help:

1. Check the [Troubleshooting Guide](TROUBLESHOOTING.md)
2. Review PocketBase documentation: https://pocketbase.io/docs/
3. Check system logs for error messages