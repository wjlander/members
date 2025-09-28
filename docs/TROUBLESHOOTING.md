# Troubleshooting Guide

This guide helps resolve common issues with the Member Management System.

## Quick Diagnostic Steps

Before diving into specific issues, run these basic checks:

```bash
# Check service status
sudo systemctl status pocketbase

# Check system resources
df -h
free -h

# View recent logs
sudo journalctl -u pocketbase --no-pager -l -n 50

# Test network connectivity
curl -I http://localhost:8080
```

## Common Issues

### 1. Service Won't Start

#### Symptoms
- Application unreachable
- Error 502/503 from web browser
- Service shows as "failed" or "inactive"

#### Diagnostic Commands
```bash
# Check detailed service status
sudo systemctl status pocketbase -l

# View service logs
sudo journalctl -u pocketbase -f

# Check if port is in use
sudo netstat -tulpn | grep :8080

# Verify file permissions
sudo ls -la /opt/member-management/
sudo ls -la /var/lib/pocketbase/
```

#### Common Causes & Solutions

**Cause: Permission Issues**
```bash
# Fix ownership
sudo chown -R pocketbase:pocketbase /var/lib/pocketbase
sudo chown pocketbase:pocketbase /opt/member-management/pocketbase
sudo chmod +x /opt/member-management/pocketbase
```

**Cause: Port Already in Use**
```bash
# Find process using port 8080
sudo lsof -i :8080

# Kill conflicting process (if safe)
sudo kill <PID>

# Or change PocketBase port in service file
sudo nano /etc/systemd/system/pocketbase.service
# Change --http=127.0.0.1:8080 to --http=127.0.0.1:8081
sudo systemctl daemon-reload
sudo systemctl restart pocketbase
```

**Cause: Disk Space Full**
```bash
# Check disk usage
df -h

# Clean up if needed
sudo apt autoremove
sudo apt autoclean

# Check log files
sudo du -h /var/log/
sudo logrotate -f /etc/logrotate.conf
```

**Cause: Corrupted Database**
```bash
# Stop service
sudo systemctl stop pocketbase

# Restore from backup
cd /var/lib/pocketbase
sudo tar -xzf backups/pocketbase_backup_YYYYMMDD_HHMMSS.tar.gz

# Fix permissions
sudo chown -R pocketbase:pocketbase /var/lib/pocketbase

# Start service
sudo systemctl start pocketbase
```

### 2. Web Interface Not Loading

#### Symptoms
- Blank page or loading spinner
- Browser console errors
- Nginx 502/503 errors

#### Diagnostic Steps

**Check Nginx**
```bash
# Test Nginx configuration
sudo nginx -t

# Check Nginx status
sudo systemctl status nginx

# View Nginx logs
sudo tail -f /var/log/nginx/error.log
sudo tail -f /var/log/nginx/access.log
```

**Check PocketBase Backend**
```bash
# Test direct connection to PocketBase
curl -I http://127.0.0.1:8080

# Check if PocketBase is responding
curl http://127.0.0.1:8080/api/health
```

#### Solutions

**Nginx Configuration Issues**
```bash
# Verify site is enabled
sudo ls -la /etc/nginx/sites-enabled/

# Re-enable site if missing
sudo ln -sf /etc/nginx/sites-available/member-management /etc/nginx/sites-enabled/

# Restart Nginx
sudo systemctl restart nginx
```

**Backend Not Responding**
```bash
# Restart PocketBase
sudo systemctl restart pocketbase

# Wait and test
sleep 10
curl -I http://127.0.0.1:8080
```

**SSL Certificate Issues**
```bash
# Check certificate status
sudo certbot certificates

# Renew if expired
sudo certbot renew

# Test HTTPS
curl -I https://your-domain.com
```

### 3. Login Issues

#### Symptoms
- "Invalid credentials" error
- Login form not submitting
- Users can't access after registration

#### Diagnostic Steps

**Check User Status**
1. Access PocketBase admin: `https://your-domain.com/_/`
2. Navigate to Users collection
3. Find the user and check:
   - Email address spelling
   - Account status
   - Association assignment

**Check Browser Console**
1. Open browser developer tools (F12)
2. Look for JavaScript errors
3. Check network tab for failed requests

#### Solutions

**User Account Issues**
```bash
# Reset user password via admin panel
# 1. Go to https://your-domain.com/_/
# 2. Users collection
# 3. Edit user
# 4. Set new password
```

**Association Mismatch**
- Verify user is assigned to correct association
- Check association is active
- Ensure member record exists for user

**Browser Issues**
```bash
# Clear browser cache and cookies
# Try incognito/private browsing mode
# Test with different browser
```

### 4. Email/Password Reset Not Working

#### Symptoms
- Password reset emails not received
- Email functionality not working

#### Diagnostic Steps

**Check Email Configuration**
1. Access PocketBase admin panel
2. Go to Settings > Mail settings
3. Verify SMTP configuration

**Test Email Sending**
```bash
# Test system mail
echo "Test email" | mail -s "Test Subject" user@example.com

# Check mail logs
sudo tail -f /var/log/mail.log
```

#### Solutions

**Configure Email Settings**
1. Access admin panel: `https://p.ringing.org.uk/_/`
2. Settings > Mail settings
3. Configure SMTP settings:
   - SMTP host
   - Port (587 for TLS, 465 for SSL)
   - Username and password
   - TLS/SSL settings

**Alternative: Manual Password Reset**
1. Access admin panel
2. Users collection
3. Find user
4. Edit and set new password
5. Inform user of temporary password

### 5. File Upload Issues

#### Symptoms
- Documents won't upload
- Upload progress stalls
- File size errors

#### Diagnostic Steps

**Check File Size Limits**
```bash
# Check Nginx upload limit
grep client_max_body_size /etc/nginx/sites-available/member-management

# Check disk space
df -h /var/lib/pocketbase
```

**Check File Permissions**
```bash
# Verify PocketBase can write files
sudo ls -la /var/lib/pocketbase/
sudo -u pocketbase touch /var/lib/pocketbase/test_file
```

#### Solutions

**Increase Upload Limits**
```nginx
# Edit Nginx config
sudo nano /etc/nginx/sites-available/member-management

# Add or modify:
client_max_body_size 100M;

# Restart Nginx
sudo systemctl restart nginx
```

**Fix File Permissions**
```bash
sudo chown -R pocketbase:pocketbase /var/lib/pocketbase
sudo chmod -R 755 /var/lib/pocketbase
```

### 6. Performance Issues

#### Symptoms
- Slow page loading
- Timeouts
- High server load

#### Diagnostic Steps

**Check System Resources**
```bash
# CPU and memory usage
top
htop

# Disk I/O
iotop

# Network connections
netstat -an | grep :8080

# Database size
sudo du -h /var/lib/pocketbase/
```

#### Solutions

**Optimize Database**
```bash
# Access admin panel and check for:
# - Large number of records
# - Unused collections
# - Large file uploads

# Consider archiving old data
# Implement pagination for large datasets
```

**Server Optimization**
```bash
# Increase swap if needed
sudo fallocate -l 1G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Add to /etc/fstab for persistence
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

### 7. Backup and Restore Issues

#### Symptoms
- Backup script fails
- Cannot restore from backup
- Backups not created automatically

#### Diagnostic Steps

**Check Backup Script**
```bash
# Test backup manually
sudo /usr/local/bin/backup-pocketbase

# Check backup directory
ls -la /var/lib/pocketbase/backups/

# Verify cron job
sudo crontab -l
```

**Check Backup Logs**
```bash
sudo tail -f /var/log/pocketbase/backup.log
```

#### Solutions

**Fix Backup Permissions**
```bash
sudo chmod +x /usr/local/bin/backup-pocketbase
sudo chown root:root /usr/local/bin/backup-pocketbase
```

**Restore Process**
```bash
# Stop service
sudo systemctl stop pocketbase

# Backup current data (safety)
sudo mv /var/lib/pocketbase/pb_data /var/lib/pocketbase/pb_data.backup

# Extract backup
cd /var/lib/pocketbase
sudo tar -xzf backups/pocketbase_backup_YYYYMMDD_HHMMSS.tar.gz

# Fix permissions
sudo chown -R pocketbase:pocketbase /var/lib/pocketbase

# Start service
sudo systemctl start pocketbase

# Verify
curl -I http://127.0.0.1:8080
```

### 8. SSL Certificate Issues

#### Symptoms
- HTTPS not working
- Certificate expired warnings
- Mixed content errors

#### Diagnostic Steps

**Check Certificate Status**
```bash
sudo certbot certificates

# Check certificate validity
openssl x509 -in /etc/letsencrypt/live/your-domain.com/cert.pem -text -noout
```

#### Solutions

**Renew Certificate**
```bash
# Manual renewal
sudo certbot renew

# Force renewal if needed
sudo certbot renew --force-renewal

# Restart Nginx
sudo systemctl restart nginx
```

**Fix Auto-Renewal**
```bash
# Check certbot timer
sudo systemctl status certbot.timer

# Enable if not active
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer

# Test auto-renewal
sudo certbot renew --dry-run
```

## Advanced Troubleshooting

### Log Analysis

**Important Log Locations**
```bash
# PocketBase service logs
sudo journalctl -u pocketbase -f

# Nginx access logs
sudo tail -f /var/log/nginx/access.log

# Nginx error logs
sudo tail -f /var/log/nginx/error.log

# System logs
sudo tail -f /var/log/syslog

# Authentication logs
sudo tail -f /var/log/auth.log
```

**Log Analysis Tips**
1. Look for patterns in error messages
2. Note timestamps of issues
3. Correlate errors across different logs
4. Check for repeated error messages

### Database Issues

**Database Corruption**
```bash
# Stop PocketBase
sudo systemctl stop pocketbase

# Check database integrity (if using SQLite)
sqlite3 /var/lib/pocketbase/pb_data/data.db "PRAGMA integrity_check;"

# Repair if needed
sqlite3 /var/lib/pocketbase/pb_data/data.db "PRAGMA auto_vacuum = FULL;"
```

**Migration Problems**
1. Access admin panel: `https://p.ringing.org.uk/_/`
2. Check Logs section for migration errors
3. Review Collections for schema issues
4. Restore from backup if migration fails

### Network Troubleshooting

**Connection Issues**
```bash
# Test internal connectivity
curl -I http://127.0.0.1:8080

# Test external connectivity
curl -I https://member.ringing.org.uk

# Check DNS resolution
nslookup member.ringing.org.uk

# Trace network path
traceroute member.ringing.org.uk
```

**Firewall Issues**
```bash
# Check UFW status
sudo ufw status

# Check iptables
sudo iptables -L

# Temporarily disable firewall for testing
sudo ufw disable
# (Remember to re-enable: sudo ufw enable)
```

## Prevention and Monitoring

### Health Monitoring

**Create Health Check Script**
```bash
sudo nano /usr/local/bin/health-check

#!/bin/bash
# Health check script
if curl -f -s http://127.0.0.1:8080/api/health > /dev/null; then
    echo "$(date): System healthy"
else
    echo "$(date): System down - restarting service"
    systemctl restart pocketbase
fi
```

```bash
sudo chmod +x /usr/local/bin/health-check

# Add to cron for regular checks
echo "*/5 * * * * /usr/local/bin/health-check >> /var/log/health-check.log" | sudo crontab -
```

### Automated Alerts

**Setup Log Monitoring**
```bash
# Install logwatch
sudo apt install logwatch

# Configure for daily reports
sudo logwatch --output mail --mailto admin@your-domain.com --detail high
```

**Disk Space Monitoring**
```bash
sudo nano /usr/local/bin/disk-check

#!/bin/bash
THRESHOLD=90
USAGE=$(df /var/lib/pocketbase | tail -1 | awk '{print $5}' | sed 's/%//')

if [ $USAGE -gt $THRESHOLD ]; then
    echo "Disk usage is ${USAGE}% - exceeds threshold of ${THRESHOLD}%"
    # Add email notification here
fi
```

### Maintenance Schedule

**Daily Tasks**
- Check service status
- Review error logs
- Monitor disk usage

**Weekly Tasks**
- Review backup integrity
- Check SSL certificate expiry
- Update system packages

**Monthly Tasks**
- Full system backup
- Security updates
- Performance review

## Getting Additional Help

### Support Resources

1. **System Logs**: Always check logs first
2. **PocketBase Documentation**: https://pocketbase.io/docs/
3. **Community Forums**: Search for similar issues
4. **GitHub Issues**: Check for known bugs

### Creating Support Tickets

When requesting help, include:

1. **System Information**:
   ```bash
   uname -a
   cat /etc/os-release
   sudo systemctl --version
   ```

2. **Service Status**:
   ```bash
   sudo systemctl status pocketbase
   sudo systemctl status nginx
   ```

3. **Recent Logs**:
   ```bash
   sudo journalctl -u pocketbase --no-pager -l -n 100
   ```

4. **Configuration Details**:
   - Nginx configuration
   - Service configuration
   - Any recent changes

5. **Steps to Reproduce**: Clear description of the issue and steps that led to it

### Emergency Contacts

- **System Administrator**: [Your admin contact]
- **Technical Support**: [Support contact]
- **Emergency Hotline**: [Emergency contact for critical issues]

Remember: Always test solutions in a development environment first when possible, and ensure you have recent backups before making significant changes.