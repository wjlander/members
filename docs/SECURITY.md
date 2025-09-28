# Security Guide

This comprehensive guide covers security best practices, configuration, and maintenance for the Member Management System.

## Table of Contents

1. [Security Overview](#security-overview)
2. [Server Security](#server-security)
3. [Application Security](#application-security)
4. [Data Protection](#data-protection)
5. [Access Control](#access-control)
6. [Monitoring and Auditing](#monitoring-and-auditing)
7. [Incident Response](#incident-response)
8. [Security Maintenance](#security-maintenance)

## Security Overview

### Security Architecture

The system implements multiple layers of security:

1. **Infrastructure Security**: Server hardening, firewall, fail2ban
2. **Transport Security**: HTTPS/TLS encryption, secure headers
3. **Application Security**: Authentication, authorization, input validation
4. **Data Security**: Encryption at rest, secure backups
5. **Operational Security**: Monitoring, logging, incident response

### Security Principles

- **Defense in Depth**: Multiple security layers
- **Principle of Least Privilege**: Minimal required access
- **Zero Trust**: Verify all access requests
- **Regular Updates**: Keep all components current
- **Monitoring**: Continuous security monitoring

## Server Security

### Operating System Hardening

#### User Management

```bash
# Disable root login via SSH
sudo sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config

# Create dedicated admin user
sudo adduser adminuser
sudo usermod -aG sudo adminuser

# Disable password authentication (use SSH keys)
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

# Restart SSH service
sudo systemctl restart ssh
```

#### SSH Hardening

```bash
# Edit SSH configuration
sudo nano /etc/ssh/sshd_config

# Recommended settings:
Port 2022                    # Change from default 22
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 0
AllowUsers adminuser pocketbase
Protocol 2
```

#### System Updates

```bash
# Enable automatic security updates
sudo apt install unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades

# Configure automatic updates
sudo nano /etc/apt/apt.conf.d/50unattended-upgrades

# Ensure these lines are uncommented:
"${distro_id}:${distro_codename}-security";
"${distro_id}ESM:${distro_codename}";
```

### Firewall Configuration

#### UFW Setup

```bash
# Reset firewall rules
sudo ufw --force reset

# Default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH (use custom port if changed)
sudo ufw allow 2022/tcp

# Allow HTTP and HTTPS
sudo ufw allow 'Nginx Full'

# Enable firewall
sudo ufw enable

# Check status
sudo ufw status verbose
```

#### Advanced Firewall Rules

```bash
# Rate limiting for SSH
sudo ufw limit 2022/tcp

# Allow specific IP ranges (adjust as needed)
sudo ufw allow from 192.168.1.0/24 to any port 2022

# Log denied connections
sudo ufw logging medium
```

### Fail2Ban Configuration

#### Basic Setup

```bash
# Create local configuration
sudo nano /etc/fail2ban/jail.local

[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
backend = systemd

[sshd]
enabled = true
port = 2022
logpath = %(sshd_log)s
maxretry = 3

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
logpath = /var/log/nginx/error.log
maxretry = 3

[nginx-noscript]
enabled = true
filter = nginx-noscript
logpath = /var/log/nginx/access.log
maxretry = 6

[nginx-badbots]
enabled = true
filter = nginx-badbots
logpath = /var/log/nginx/access.log
maxretry = 2
```

#### Custom Filters for PocketBase

```bash
# Create PocketBase filter
sudo nano /etc/fail2ban/filter.d/pocketbase.conf

[Definition]
failregex = ^<HOST>.*"POST.*/_/" .* 40[13] 
            ^<HOST>.*"POST.*/api/auth" .* 40[03]
ignoreregex =

# Add to jail.local
[pocketbase]
enabled = true
filter = pocketbase
logpath = /var/log/nginx/access.log
maxretry = 5
bantime = 1800
```

### File System Security

#### Secure Permissions

```bash
# Set secure permissions for application files
sudo chmod 755 /opt/member-management
sudo chmod 500 /opt/member-management/pocketbase
sudo chown root:root /opt/member-management/pocketbase

# Secure data directory
sudo chmod 750 /var/lib/pocketbase
sudo chown pocketbase:pocketbase /var/lib/pocketbase

# Secure log files
sudo chmod 640 /var/log/pocketbase/*
sudo chown pocketbase:adm /var/log/pocketbase/*
```

#### File Integrity Monitoring

```bash
# Install AIDE (Advanced Intrusion Detection Environment)
sudo apt install aide

# Initialize database
sudo aide --init
sudo mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db

# Create check script
sudo nano /usr/local/bin/integrity-check

#!/bin/bash
aide --check | logger -t "AIDE"
if [ $? -ne 0 ]; then
    echo "File integrity check failed!" | mail -s "Security Alert" admin@yourdomain.com
fi

# Schedule daily checks
echo "0 3 * * * /usr/local/bin/integrity-check" | sudo crontab -
```

## Application Security

### HTTPS Configuration

#### SSL/TLS Best Practices

```nginx
# Enhanced SSL configuration for Nginx
server {
    listen 443 ssl http2;
    server_name member.ringing.org.uk;
    
    # SSL certificate configuration
    ssl_certificate /etc/letsencrypt/live/member.ringing.org.uk/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/member.ringing.org.uk/privkey.pem;
    
    # SSL security settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # OCSP stapling
    ssl_stapling on;
    ssl_stapling_verify on;
    ssl_trusted_certificate /etc/letsencrypt/live/member.ringing.org.uk/chain.pem;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' cdn.tailwindcss.com unpkg.com cdnjs.cloudflare.com; style-src 'self' 'unsafe-inline' cdn.tailwindcss.com cdnjs.cloudflare.com; font-src 'self' cdnjs.cloudflare.com; img-src 'self' data:; connect-src 'self';" always;
    
    # Remove server tokens
    server_tokens off;
    
    # Prevent clickjacking
    add_header X-Frame-Options SAMEORIGIN always;
    
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Security headers for proxied content
        proxy_hide_header X-Powered-By;
        proxy_hide_header Server;
    }
}

# Redirect HTTP to HTTPS
server {
    listen 80;
    server_name member.ringing.org.uk;
    return 301 https://$server_name$request_uri;
}
```

### PocketBase Security Configuration

#### Admin Panel Security

```bash
# Access admin panel configuration
# Navigate to https://p.ringing.org.uk/_/

# Implement these security measures:
# 1. Strong admin passwords (minimum 12 characters)
# 2. Enable two-factor authentication if available
# 3. Restrict admin panel access by IP if possible
# 4. Regular password rotation (every 90 days)
```

#### API Security

```bash
# Configure rate limiting in Nginx
location /api/ {
    limit_req zone=api burst=10 nodelay;
    limit_req_status 429;
    
    proxy_pass http://127.0.0.1:8080;
    # ... other proxy settings
}

# Add rate limiting zone to nginx.conf
http {
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/m;
    # ... other configurations
}
```

### Authentication Security

#### Password Policies

Configure in PocketBase admin panel:
- Minimum length: 8 characters
- Complexity requirements: Mix of letters, numbers, symbols
- Password history: Prevent reuse of last 5 passwords
- Account lockout: After 5 failed attempts

#### Session Security

```bash
# Configure session settings in PocketBase
# Access admin panel > Settings > Auth

# Recommended settings:
# - Session timeout: 24 hours
# - Remember me duration: 7 days maximum
# - Require email verification: Enabled
# - Password reset token duration: 1 hour
```

## Data Protection

### Encryption at Rest

#### Database Encryption

```bash
# For enhanced security, consider database encryption
# This requires additional setup and key management

# Create encrypted backup script
sudo nano /usr/local/bin/encrypted-backup

#!/bin/bash
BACKUP_DIR="/var/lib/pocketbase/backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/pocketbase_backup_$DATE.tar.gz"
ENCRYPTED_FILE="$BACKUP_FILE.gpg"

# Create backup
tar -czf "$BACKUP_FILE" -C /var/lib/pocketbase pb_data pb_migrations

# Encrypt backup
gpg --symmetric --cipher-algo AES256 --output "$ENCRYPTED_FILE" "$BACKUP_FILE"

# Remove unencrypted backup
rm "$BACKUP_FILE"

echo "Encrypted backup created: $ENCRYPTED_FILE"
```

#### File Upload Security

```bash
# Configure file upload restrictions in PocketBase admin panel:
# 1. Maximum file size: 10MB
# 2. Allowed file types: PDF, DOC, DOCX, JPG, PNG
# 3. Virus scanning (if available)
# 4. File quarantine for suspicious uploads
```

### Data Loss Prevention

#### Backup Security

```bash
# Secure backup permissions
sudo chmod 600 /var/lib/pocketbase/backups/*
sudo chown pocketbase:pocketbase /var/lib/pocketbase/backups/*

# Create backup verification script
sudo nano /usr/local/bin/verify-backups

#!/bin/bash
BACKUP_DIR="/var/lib/pocketbase/backups"
LOG_FILE="/var/log/pocketbase/backup-verification.log"

for backup in "$BACKUP_DIR"/*.tar.gz; do
    if tar -tzf "$backup" >/dev/null 2>&1; then
        echo "$(date): PASS - $backup" >> "$LOG_FILE"
    else
        echo "$(date): FAIL - $backup" >> "$LOG_FILE"
        # Send alert
        echo "Backup verification failed for $backup" | mail -s "Backup Alert" admin@yourdomain.com
    fi
done
```

#### Data Sanitization

```bash
# Regular data cleanup script
sudo nano /usr/local/bin/data-cleanup

#!/bin/bash
# Remove old session data, temporary files, etc.
# This script should be customized based on your data retention policies

# Clean old logs (older than 90 days)
find /var/log/pocketbase -name "*.log" -mtime +90 -delete

# Archive old member data (if applicable)
# Implement based on your data retention requirements
```

## Access Control

### User Role Management

#### Role-Based Access Control (RBAC)

Configure in PocketBase admin panel:

1. **Super Admin Role**:
   - Full system access
   - All associations
   - User management
   - System configuration

2. **Association Admin Role**:
   - Association-specific access
   - Member management
   - Reports and analytics
   - Association settings

3. **Member Role**:
   - Own profile management
   - Dues payment
   - Document upload
   - Read-only access to association info

#### Permission Auditing

```bash
# Create user audit script
sudo nano /usr/local/bin/user-audit

#!/bin/bash
# Access PocketBase API to audit user permissions
# This requires API integration and should be customized
# based on your specific audit requirements

echo "User Audit Report - $(date)" > /tmp/user-audit.txt
echo "================================" >> /tmp/user-audit.txt

# List all admin users
echo "Admin Users:" >> /tmp/user-audit.txt
# Add API calls to list admin users

# List users with elevated privileges
echo "Elevated Privilege Users:" >> /tmp/user-audit.txt
# Add API calls to check user roles

# Send report
mail -s "User Audit Report" admin@yourdomain.com < /tmp/user-audit.txt
```

### API Access Control

#### API Security

```bash
# Implement API rate limiting
location /api/ {
    # Rate limiting
    limit_req zone=api burst=20 nodelay;
    
    # IP whitelisting for admin API (optional)
    # allow 192.168.1.0/24;
    # deny all;
    
    proxy_pass http://127.0.0.1:8080;
    # ... other settings
}
```

#### Authentication Token Security

- **Token Expiration**: Set appropriate token lifetimes
- **Token Rotation**: Implement regular token refresh
- **Secure Storage**: Store tokens securely on client side
- **Token Revocation**: Provide mechanism to revoke tokens

## Monitoring and Auditing

### Security Logging

#### Comprehensive Logging Setup

```bash
# Configure rsyslog for centralized logging
sudo nano /etc/rsyslog.d/50-pocketbase.conf

# Log PocketBase events
:programname, isequal, "pocketbase" /var/log/pocketbase/security.log
& stop

# Restart rsyslog
sudo systemctl restart rsyslog
```

#### Log Monitoring

```bash
# Create security log monitor
sudo nano /usr/local/bin/security-monitor

#!/bin/bash
LOG_FILE="/var/log/pocketbase/security.log"
ALERT_EMAIL="admin@yourdomain.com"

# Monitor for suspicious activities
if grep -q "authentication failure" "$LOG_FILE"; then
    echo "Multiple authentication failures detected" | mail -s "Security Alert" "$ALERT_EMAIL"
fi

if grep -q "unauthorized access" "$LOG_FILE"; then
    echo "Unauthorized access attempt detected" | mail -s "Security Alert" "$ALERT_EMAIL"
fi

# Check for unusual file access patterns
if grep -q "file upload" "$LOG_FILE" | wc -l > 100; then
    echo "Unusual file upload activity detected" | mail -s "Security Alert" "$ALERT_EMAIL"
fi
```

### Intrusion Detection

#### Real-time Monitoring

```bash
# Install and configure OSSEC (optional)
# For more advanced intrusion detection

# Basic file monitoring with inotify
sudo apt install inotify-tools

# Create file monitor script
sudo nano /usr/local/bin/file-monitor

#!/bin/bash
inotifywait -m -r -e modify,create,delete /var/lib/pocketbase/pb_data |
while read path action file; do
    echo "$(date): $path$file was $action" >> /var/log/pocketbase/file-activity.log
    
    # Alert on unauthorized changes
    if [[ "$path" == *"/pb_data/"* ]] && [[ "$action" == "DELETE" ]]; then
        echo "Critical: File deletion in data directory - $path$file" | \
            mail -s "File Deletion Alert" admin@yourdomain.com
    fi
done
```

### Security Auditing

#### Regular Security Audits

```bash
# Create security audit script
sudo nano /usr/local/bin/security-audit

#!/bin/bash
AUDIT_DATE=$(date +%Y%m%d)
AUDIT_FILE="/tmp/security-audit-$AUDIT_DATE.txt"

echo "Security Audit Report - $(date)" > "$AUDIT_FILE"
echo "===============================" >> "$AUDIT_FILE"

# Check system updates
echo "System Update Status:" >> "$AUDIT_FILE"
apt list --upgradable >> "$AUDIT_FILE" 2>/dev/null

# Check user accounts
echo -e "\nUser Accounts:" >> "$AUDIT_FILE"
cut -d: -f1,3 /etc/passwd | awk -F: '($2>=1000) {print $1}' >> "$AUDIT_FILE"

# Check listening services
echo -e "\nListening Services:" >> "$AUDIT_FILE"
netstat -tulpn >> "$AUDIT_FILE" 2>/dev/null

# Check firewall status
echo -e "\nFirewall Status:" >> "$AUDIT_FILE"
ufw status verbose >> "$AUDIT_FILE"

# Check fail2ban status
echo -e "\nFail2ban Status:" >> "$AUDIT_FILE"
fail2ban-client status >> "$AUDIT_FILE"

# Send audit report
mail -s "Security Audit Report" admin@yourdomain.com < "$AUDIT_FILE"

# Cleanup
rm "$AUDIT_FILE"
```

## Incident Response

### Incident Response Plan

#### Detection and Analysis

1. **Incident Detection**:
   - Automated monitoring alerts
   - User reports
   - Log analysis
   - Performance anomalies

2. **Initial Response**:
   - Isolate affected systems
   - Preserve evidence
   - Assess impact
   - Notify stakeholders

#### Containment and Recovery

```bash
# Emergency response script
sudo nano /usr/local/bin/emergency-response

#!/bin/bash
# Emergency incident response script

case "$1" in
    "isolate")
        # Isolate system from network
        sudo ufw deny incoming
        sudo systemctl stop nginx
        echo "System isolated from network"
        ;;
    "preserve")
        # Preserve evidence
        EVIDENCE_DIR="/tmp/incident-$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$EVIDENCE_DIR"
        
        # Copy logs
        cp -r /var/log/pocketbase "$EVIDENCE_DIR/"
        cp -r /var/log/nginx "$EVIDENCE_DIR/"
        
        # System state
        ps aux > "$EVIDENCE_DIR/processes.txt"
        netstat -tulpn > "$EVIDENCE_DIR/network.txt"
        
        echo "Evidence preserved in $EVIDENCE_DIR"
        ;;
    "restore")
        # Restore from clean backup
        systemctl stop pocketbase
        # Restore from known good backup
        # (implementation depends on incident type)
        systemctl start pocketbase
        echo "System restored from backup"
        ;;
    *)
        echo "Usage: $0 {isolate|preserve|restore}"
        ;;
esac
```

#### Communication Plan

1. **Internal Communication**:
   - IT team notification
   - Management updates
   - Legal/compliance teams

2. **External Communication**:
   - User notifications
   - Regulatory reporting
   - Law enforcement (if required)

### Forensic Procedures

#### Evidence Collection

```bash
# Digital forensics script
sudo nano /usr/local/bin/collect-evidence

#!/bin/bash
INCIDENT_ID="$1"
EVIDENCE_DIR="/var/evidence/incident-$INCIDENT_ID"

if [ -z "$INCIDENT_ID" ]; then
    echo "Usage: $0 <incident_id>"
    exit 1
fi

mkdir -p "$EVIDENCE_DIR"

# System information
uname -a > "$EVIDENCE_DIR/system-info.txt"
date > "$EVIDENCE_DIR/collection-time.txt"

# Process information
ps auxf > "$EVIDENCE_DIR/processes.txt"

# Network connections
netstat -tulpnW > "$EVIDENCE_DIR/network-connections.txt"

# File system information
find /var/lib/pocketbase -type f -exec ls -la {} \; > "$EVIDENCE_DIR/file-permissions.txt"

# Hash all critical files
find /var/lib/pocketbase -type f -exec md5sum {} \; > "$EVIDENCE_DIR/file-hashes.txt"

# Copy logs (preserve timestamps)
cp -p /var/log/pocketbase/* "$EVIDENCE_DIR/" 2>/dev/null
cp -p /var/log/nginx/* "$EVIDENCE_DIR/" 2>/dev/null
cp -p /var/log/auth.log "$EVIDENCE_DIR/"
cp -p /var/log/syslog "$EVIDENCE_DIR/"

# Create evidence package
tar -czf "$EVIDENCE_DIR.tar.gz" -C /var/evidence "incident-$INCIDENT_ID"

echo "Evidence collected: $EVIDENCE_DIR.tar.gz"
```

## Security Maintenance

### Regular Security Tasks

#### Daily Tasks
- Monitor security logs
- Check failed login attempts
- Verify backup completion
- Review system alerts

#### Weekly Tasks
- Update fail2ban rules
- Review user access
- Check SSL certificate status
- Analyze security logs

#### Monthly Tasks
- Security patch updates
- User access audit
- Backup testing
- Security configuration review

### Security Updates

#### Automated Security Updates

```bash
# Configure unattended upgrades for security updates
sudo nano /etc/apt/apt.conf.d/50unattended-upgrades

Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "03:00";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Mail "admin@yourdomain.com";
```

#### Manual Update Process

```bash
# Create update script
sudo nano /usr/local/bin/security-updates

#!/bin/bash
# Pre-update backup
/usr/local/bin/backup-pocketbase

# System updates
apt update
apt list --upgradable

# Install security updates
apt upgrade -y

# PocketBase updates (manual process)
# Check https://github.com/pocketbase/pocketbase/releases

# Restart services if needed
systemctl restart nginx
systemctl restart pocketbase

# Post-update verification
systemctl status pocketbase
systemctl status nginx

echo "Security updates completed: $(date)"
```

### Compliance and Documentation

#### Security Documentation

Maintain documentation for:
- Security policies and procedures
- Incident response plans
- User access controls
- Data protection measures
- Audit logs and reports

#### Compliance Monitoring

```bash
# Compliance check script
sudo nano /usr/local/bin/compliance-check

#!/bin/bash
# Check compliance with security standards

REPORT_FILE="/tmp/compliance-report-$(date +%Y%m%d).txt"

echo "Compliance Check Report - $(date)" > "$REPORT_FILE"
echo "=================================" >> "$REPORT_FILE"

# Check encryption status
echo "Encryption Status:" >> "$REPORT_FILE"
if systemctl is-active nginx | grep -q "active"; then
    echo "✓ HTTPS enabled" >> "$REPORT_FILE"
else
    echo "✗ HTTPS not properly configured" >> "$REPORT_FILE"
fi

# Check backup status
echo "Backup Status:" >> "$REPORT_FILE"
if [ -f "/var/lib/pocketbase/backups/pocketbase_backup_$(date +%Y%m%d)*.tar.gz" ]; then
    echo "✓ Daily backup completed" >> "$REPORT_FILE"
else
    echo "✗ Daily backup missing" >> "$REPORT_FILE"
fi

# Check access controls
echo "Access Controls:" >> "$REPORT_FILE"
if ufw status | grep -q "Status: active"; then
    echo "✓ Firewall active" >> "$REPORT_FILE"
else
    echo "✗ Firewall not active" >> "$REPORT_FILE"
fi

# Send compliance report
mail -s "Compliance Check Report" admin@yourdomain.com < "$REPORT_FILE"
```

## Security Resources

### Additional Security Tools

1. **Vulnerability Scanners**:
   - OpenVAS
   - Nessus
   - Nikto (web vulnerability)

2. **Network Security**:
   - Nmap (network discovery)
   - Wireshark (packet analysis)
   - TCPdump (network monitoring)

3. **Log Analysis**:
   - ELK Stack (Elasticsearch, Logstash, Kibana)
   - Splunk
   - Graylog

### Security Communities and Resources

- **OWASP**: Web application security guidelines
- **NIST**: Cybersecurity framework
- **CIS Controls**: Security best practices
- **CVE Database**: Known vulnerabilities

### Emergency Contacts

- **System Administrator**: [Your contact]
- **Security Team**: [Security contact]
- **Incident Response**: [Emergency hotline]
- **Legal/Compliance**: [Legal contact]

Remember: Security is an ongoing process, not a one-time setup. Regular reviews, updates, and monitoring are essential for maintaining a secure system.