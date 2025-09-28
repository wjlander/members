# Backup and Recovery Guide

This guide covers comprehensive backup strategies, recovery procedures, and best practices for the Member Management System.

## Table of Contents

1. [Backup Overview](#backup-overview)
2. [Automated Backup System](#automated-backup-system)
3. [Manual Backup Procedures](#manual-backup-procedures)
4. [Recovery Procedures](#recovery-procedures)
5. [Testing and Validation](#testing-and-validation)
6. [Best Practices](#best-practices)
7. [Troubleshooting](#troubleshooting)

## Backup Overview

### What Gets Backed Up

The backup system includes:
- **Database Files**: All member data, associations, dues
- **Configuration Files**: System settings and schema
- **Uploaded Files**: Member documents and attachments
- **Migration History**: Database schema changes

### Backup Components

1. **PocketBase Data Directory**: `/var/lib/pocketbase/pb_data`
2. **Migration Files**: `/var/lib/pocketbase/pb_migrations`
3. **Uploaded Files**: Stored within pb_data directory
4. **System Configuration**: Service files and Nginx config

## Automated Backup System

### Default Backup Schedule

The system includes automated daily backups:
- **Time**: 2:00 AM daily
- **Retention**: 7 days of backups kept
- **Location**: `/var/lib/pocketbase/backups/`
- **Format**: Compressed tar.gz files

### Backup Script Location

The backup script is installed at: `/usr/local/bin/backup-pocketbase`

### Viewing Backup Status

```bash
# Check if backup ran today
ls -la /var/lib/pocketbase/backups/

# View backup logs
sudo tail -f /var/log/pocketbase/backup.log

# Check cron job status
sudo crontab -l | grep backup
```

### Configuring Backup Schedule

To modify the backup schedule:

```bash
# Edit cron jobs
sudo crontab -e

# Current entry (daily at 2 AM):
# 0 2 * * * /usr/local/bin/backup-pocketbase >> /var/log/pocketbase/backup.log 2>&1

# Examples of other schedules:
# Every 6 hours: 0 */6 * * *
# Weekly on Sunday: 0 2 * * 0
# Twice daily: 0 2,14 * * *
```

## Manual Backup Procedures

### Creating a Manual Backup

```bash
# Run the backup script manually
sudo /usr/local/bin/backup-pocketbase

# Or create a custom backup with specific name
BACKUP_NAME="manual_backup_$(date +%Y%m%d_%H%M%S)"
sudo tar -czf "/var/lib/pocketbase/backups/${BACKUP_NAME}.tar.gz" \
     -C /var/lib/pocketbase pb_data pb_migrations

echo "Manual backup created: ${BACKUP_NAME}.tar.gz"
```

### Pre-Maintenance Backup

Before system maintenance or updates:

```bash
# Create maintenance backup
MAINTENANCE_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="/var/lib/pocketbase/backups/pre_maintenance_${MAINTENANCE_DATE}.tar.gz"

# Stop service for consistent backup
sudo systemctl stop pocketbase

# Create backup
sudo tar -czf "$BACKUP_FILE" -C /var/lib/pocketbase pb_data pb_migrations

# Restart service
sudo systemctl start pocketbase

echo "Pre-maintenance backup created: $BACKUP_FILE"
```

### Custom Backup Script

Create a more advanced backup script:

```bash
sudo nano /usr/local/bin/advanced-backup

#!/bin/bash

BACKUP_DIR="/var/lib/pocketbase/backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/pocketbase_backup_$DATE.tar.gz"
LOG_FILE="/var/log/pocketbase/backup.log"

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

log_message "Starting backup process"

# Create backup
if tar -czf "$BACKUP_FILE" -C /var/lib/pocketbase pb_data pb_migrations; then
    log_message "Backup created successfully: $BACKUP_FILE"
    
    # Check backup integrity
    if tar -tzf "$BACKUP_FILE" >/dev/null 2>&1; then
        log_message "Backup integrity verified"
        
        # Get backup size
        BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
        log_message "Backup size: $BACKUP_SIZE"
        
        # Keep only last N backups
        KEEP_BACKUPS=7
        cd "$BACKUP_DIR"
        ls -t pocketbase_backup_*.tar.gz | tail -n +$((KEEP_BACKUPS + 1)) | xargs rm -f
        log_message "Old backups cleaned up, keeping last $KEEP_BACKUPS backups"
        
    else
        log_message "ERROR: Backup integrity check failed"
        exit 1
    fi
else
    log_message "ERROR: Backup creation failed"
    exit 1
fi

log_message "Backup process completed successfully"
```

Make it executable:
```bash
sudo chmod +x /usr/local/bin/advanced-backup
```

## Recovery Procedures

### Complete System Recovery

When you need to restore the entire system:

```bash
# 1. Stop PocketBase service
sudo systemctl stop pocketbase

# 2. Backup current data (safety measure)
sudo mv /var/lib/pocketbase/pb_data /var/lib/pocketbase/pb_data.backup-$(date +%Y%m%d_%H%M%S)

# 3. Extract backup
cd /var/lib/pocketbase
sudo tar -xzf backups/pocketbase_backup_YYYYMMDD_HHMMSS.tar.gz

# 4. Fix permissions
sudo chown -R pocketbase:pocketbase /var/lib/pocketbase

# 5. Start service
sudo systemctl start pocketbase

# 6. Verify system is working
sleep 5
curl -I http://127.0.0.1:8080
```

### Selective Recovery

To restore specific data or fix corruption:

#### Restore Database Only

```bash
# Stop service
sudo systemctl stop pocketbase

# Extract only database files
cd /tmp
sudo tar -xzf /var/lib/pocketbase/backups/pocketbase_backup_YYYYMMDD_HHMMSS.tar.gz pb_data/data.db

# Replace current database
sudo cp pb_data/data.db /var/lib/pocketbase/pb_data/data.db
sudo chown pocketbase:pocketbase /var/lib/pocketbase/pb_data/data.db

# Start service
sudo systemctl start pocketbase
```

#### Restore Uploaded Files

```bash
# Stop service
sudo systemctl stop pocketbase

# Extract file storage
cd /tmp
sudo tar -xzf /var/lib/pocketbase/backups/pocketbase_backup_YYYYMMDD_HHMMSS.tar.gz pb_data/storage

# Replace file storage
sudo rm -rf /var/lib/pocketbase/pb_data/storage
sudo cp -r pb_data/storage /var/lib/pocketbase/pb_data/
sudo chown -R pocketbase:pocketbase /var/lib/pocketbase/pb_data/storage

# Start service
sudo systemctl start pocketbase
```

### Recovery Verification

After any recovery operation:

```bash
# Check service status
sudo systemctl status pocketbase

# Test web interface
curl -I https://your-domain.com

# Check admin panel
curl -I https://your-domain.com/_/

# Verify data integrity
# Access admin panel and spot-check data
```

## Testing and Validation

### Regular Backup Testing

Monthly backup verification process:

```bash
# Create test restoration script
sudo nano /usr/local/bin/test-backup

#!/bin/bash

TEST_DIR="/tmp/backup-test-$(date +%Y%m%d_%H%M%S)"
LATEST_BACKUP=$(ls -t /var/lib/pocketbase/backups/pocketbase_backup_*.tar.gz | head -1)

echo "Testing backup: $LATEST_BACKUP"

# Create test directory
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

# Extract backup
if tar -xzf "$LATEST_BACKUP"; then
    echo "✓ Backup extraction successful"
else
    echo "✗ Backup extraction failed"
    exit 1
fi

# Check for required files
if [ -f "pb_data/data.db" ]; then
    echo "✓ Database file exists"
else
    echo "✗ Database file missing"
    exit 1
fi

# Check database integrity (if SQLite)
if sqlite3 pb_data/data.db "PRAGMA integrity_check;" | grep -q "ok"; then
    echo "✓ Database integrity check passed"
else
    echo "✗ Database integrity check failed"
    exit 1
fi

# Cleanup
rm -rf "$TEST_DIR"
echo "✓ Backup test completed successfully"
```

```bash
sudo chmod +x /usr/local/bin/test-backup

# Run test
sudo /usr/local/bin/test-backup
```

### Automated Test Schedule

Add backup testing to monthly maintenance:

```bash
sudo crontab -e

# Add line for monthly backup test (1st day of month at 3 AM):
0 3 1 * * /usr/local/bin/test-backup >> /var/log/pocketbase/backup-test.log 2>&1
```

## Remote Backup Solutions

### Cloud Storage Integration

For additional security, consider remote backups:

#### AWS S3 Integration

```bash
# Install AWS CLI
sudo apt install awscli

# Configure AWS credentials
aws configure

# Create S3 sync script
sudo nano /usr/local/bin/sync-to-s3

#!/bin/bash
LOCAL_BACKUP_DIR="/var/lib/pocketbase/backups"
S3_BUCKET="s3://your-backup-bucket/member-management/"

# Sync backups to S3
aws s3 sync "$LOCAL_BACKUP_DIR" "$S3_BUCKET" --delete

echo "Backups synced to S3: $(date)"
```

#### Alternative: rsync to Remote Server

```bash
# Setup SSH key authentication
ssh-keygen -t rsa -b 4096
ssh-copy-id backup-user@backup-server.com

# Create rsync script
sudo nano /usr/local/bin/sync-to-remote

#!/bin/bash
LOCAL_BACKUP_DIR="/var/lib/pocketbase/backups/"
REMOTE_DEST="backup-user@backup-server.com:/backups/member-management/"

# Sync to remote server
rsync -avz --delete "$LOCAL_BACKUP_DIR" "$REMOTE_DEST"

echo "Backups synced to remote server: $(date)"
```

## Best Practices

### Backup Strategy

1. **3-2-1 Rule**: 3 copies, 2 different media, 1 offsite
2. **Regular Schedule**: Daily automated backups minimum
3. **Pre-Change Backups**: Before any system modifications
4. **Test Regularly**: Monthly backup restoration tests
5. **Document Process**: Keep recovery procedures updated

### Security Considerations

1. **Encrypt Backups**: For sensitive data
2. **Secure Storage**: Protect backup files from unauthorized access
3. **Access Control**: Limit who can create/restore backups
4. **Audit Trail**: Log all backup and recovery operations

### Storage Management

1. **Retention Policy**: Define how long to keep backups
2. **Storage Monitoring**: Monitor backup storage usage
3. **Compression**: Use compression to save space
4. **Remote Storage**: Keep offsite copies for disaster recovery

### Documentation

1. **Recovery Procedures**: Document step-by-step recovery
2. **Contact Information**: Emergency contacts and procedures
3. **System Dependencies**: Note any external dependencies
4. **Version Information**: Track PocketBase versions and compatibility

## Troubleshooting

### Common Backup Issues

#### Backup Script Fails

```bash
# Check script permissions
ls -la /usr/local/bin/backup-pocketbase

# Test script manually
sudo /usr/local/bin/backup-pocketbase

# Check disk space
df -h /var/lib/pocketbase/backups/

# Check logs
sudo tail -f /var/log/pocketbase/backup.log
```

#### Restoration Fails

```bash
# Verify backup integrity
tar -tzf /var/lib/pocketbase/backups/backup_file.tar.gz

# Check file permissions
ls -la /var/lib/pocketbase/

# Verify service is stopped
sudo systemctl status pocketbase

# Check available disk space
df -h /var/lib/pocketbase/
```

#### Missing Backups

```bash
# Check cron job
sudo crontab -l

# Check cron service
sudo systemctl status cron

# Verify script exists
ls -la /usr/local/bin/backup-pocketbase

# Check system logs
sudo grep -i backup /var/log/syslog
```

### Recovery Issues

#### Service Won't Start After Recovery

```bash
# Check file ownership
sudo chown -R pocketbase:pocketbase /var/lib/pocketbase

# Check file permissions
sudo chmod -R 755 /var/lib/pocketbase
sudo chmod 644 /var/lib/pocketbase/pb_data/data.db

# Check service logs
sudo journalctl -u pocketbase -f
```

#### Data Appears Corrupted

```bash
# Check database integrity
sqlite3 /var/lib/pocketbase/pb_data/data.db "PRAGMA integrity_check;"

# Try older backup
# Follow complete system recovery with earlier backup

# Check for partial restoration
# Ensure complete backup was extracted
```

### Performance Impact

#### Backup Taking Too Long

```bash
# Monitor backup process
sudo ps aux | grep tar

# Check system resources during backup
top
iotop

# Consider:
# - Running backups during low-usage hours
# - Using incremental backups
# - Excluding large temporary files
```

#### System Slow During Backup

```bash
# Use nice/ionice for lower priority
sudo nice -n 19 ionice -c 3 /usr/local/bin/backup-pocketbase

# Modify cron job to use lower priority
0 2 * * * nice -n 19 ionice -c 3 /usr/local/bin/backup-pocketbase >> /var/log/pocketbase/backup.log 2>&1
```

## Disaster Recovery Planning

### Complete System Failure

1. **Assess Damage**: Determine what needs recovery
2. **Prepare New System**: Set up fresh server if needed
3. **Restore from Backup**: Follow complete recovery procedures
4. **Verify Integrity**: Test all system functions
5. **Update DNS**: Point domain to new server if changed
6. **Communicate**: Inform users of status and expected restoration

### Data Center Outage

1. **Activate Backup Site**: If available
2. **Restore from Offsite Backup**: Use remote backup copies
3. **Update Infrastructure**: Modify DNS, SSL certificates
4. **Test Functionality**: Verify all features work
5. **Monitor Performance**: Ensure adequate resources

### Long-term Archival

For regulatory compliance or long-term storage:

```bash
# Create annual archive
YEAR=$(date +%Y)
ARCHIVE_NAME="annual_archive_${YEAR}.tar.gz"

sudo tar -czf "/var/lib/pocketbase/archives/${ARCHIVE_NAME}" \
     -C /var/lib/pocketbase pb_data pb_migrations

# Move to long-term storage
# aws s3 cp "/var/lib/pocketbase/archives/${ARCHIVE_NAME}" s3://long-term-storage/
```

Remember: Regular testing and documentation updates are crucial for an effective backup and recovery strategy.