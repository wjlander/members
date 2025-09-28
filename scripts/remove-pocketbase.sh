#!/bin/bash

# Complete PocketBase Removal Script
# This script removes all traces of PocketBase from the server

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root or with sudo privileges"
   exit 1
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}    Complete PocketBase Removal        ${NC}"
echo -e "${BLUE}========================================${NC}"
echo

warn "This will completely remove PocketBase from your server."
warn "Make sure you have backed up any important data!"
echo

read -p "Are you sure you want to continue? (y/N): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Removal cancelled."
    exit 0
fi

log "Starting PocketBase removal process..."

# 1. Stop PocketBase service
log "Stopping PocketBase service..."
if systemctl is-active --quiet pocketbase 2>/dev/null; then
    systemctl stop pocketbase
    log "PocketBase service stopped"
else
    log "PocketBase service was not running"
fi

# 2. Disable PocketBase service
log "Disabling PocketBase service..."
if systemctl is-enabled --quiet pocketbase 2>/dev/null; then
    systemctl disable pocketbase
    log "PocketBase service disabled"
else
    log "PocketBase service was not enabled"
fi

# 3. Remove systemd service file
log "Removing systemd service file..."
if [[ -f "/etc/systemd/system/pocketbase.service" ]]; then
    rm -f "/etc/systemd/system/pocketbase.service"
    log "Systemd service file removed"
else
    log "Systemd service file not found"
fi

# Reload systemd daemon
systemctl daemon-reload

# 4. Remove PocketBase binary and application directory
log "Removing PocketBase application files..."
if [[ -d "/opt/member-management" ]]; then
    # Check if it contains PocketBase binary
    if [[ -f "/opt/member-management/pocketbase" ]]; then
        rm -f "/opt/member-management/pocketbase"
        log "PocketBase binary removed from /opt/member-management"
    fi
    
    # Remove any PocketBase-related files but keep the directory for new system
    find /opt/member-management -name "*pocketbase*" -type f -delete 2>/dev/null || true
    log "PocketBase-related files cleaned from application directory"
else
    log "Application directory not found"
fi

# Also check common PocketBase locations
POCKETBASE_LOCATIONS=(
    "/usr/local/bin/pocketbase"
    "/usr/bin/pocketbase"
    "/opt/pocketbase"
    "/home/pocketbase"
)

for location in "${POCKETBASE_LOCATIONS[@]}"; do
    if [[ -f "$location" ]] || [[ -d "$location" ]]; then
        rm -rf "$location"
        log "Removed PocketBase from: $location"
    fi
done

# 5. Remove PocketBase data directory (with backup option)
log "Handling PocketBase data directory..."
if [[ -d "/var/lib/pocketbase" ]]; then
    warn "Found PocketBase data directory: /var/lib/pocketbase"
    
    # Check if there's important data
    if [[ -f "/var/lib/pocketbase/pb_data/data.db" ]]; then
        warn "Database file found. Creating backup before removal..."
        
        # Create backup directory
        BACKUP_DIR="/tmp/pocketbase-backup-$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$BACKUP_DIR"
        
        # Copy data to backup
        cp -r /var/lib/pocketbase "$BACKUP_DIR/"
        log "Backup created at: $BACKUP_DIR"
        
        echo
        warn "IMPORTANT: Your PocketBase data has been backed up to:"
        warn "$BACKUP_DIR"
        warn "If you need this data later, copy it to a safe location."
        echo
        
        read -p "Remove PocketBase data directory now? (y/N): " remove_data
        if [[ "$remove_data" == "y" || "$remove_data" == "Y" ]]; then
            rm -rf /var/lib/pocketbase
            log "PocketBase data directory removed"
        else
            log "PocketBase data directory preserved"
        fi
    else
        # No database file, safe to remove
        rm -rf /var/lib/pocketbase
        log "PocketBase data directory removed (no database found)"
    fi
else
    log "PocketBase data directory not found"
fi

# 6. Remove PocketBase user
log "Removing PocketBase user..."
if id "pocketbase" &>/dev/null; then
    userdel -r pocketbase 2>/dev/null || userdel pocketbase 2>/dev/null || true
    log "PocketBase user removed"
else
    log "PocketBase user not found"
fi

# 7. Remove PocketBase-related Nginx configurations
log "Removing PocketBase Nginx configurations..."
NGINX_CONFIGS=(
    "/etc/nginx/sites-available/member-management"
    "/etc/nginx/sites-available/pocketbase"
    "/etc/nginx/sites-enabled/member-management"
    "/etc/nginx/sites-enabled/pocketbase"
)

for config in "${NGINX_CONFIGS[@]}"; do
    if [[ -f "$config" ]]; then
        # Check if it's PocketBase-related
        if grep -q "pocketbase\|8080" "$config" 2>/dev/null; then
            rm -f "$config"
            log "Removed PocketBase Nginx config: $config"
        fi
    fi
done

# 8. Remove PocketBase-related cron jobs
log "Removing PocketBase cron jobs..."
if [[ -f "/etc/cron.daily/pocketbase-backup" ]]; then
    rm -f "/etc/cron.daily/pocketbase-backup"
    log "Removed PocketBase backup cron job"
fi

# Remove from user crontabs
for user in root pocketbase; do
    if crontab -u "$user" -l 2>/dev/null | grep -q "pocketbase"; then
        # Remove PocketBase entries from crontab
        crontab -u "$user" -l 2>/dev/null | grep -v "pocketbase" | crontab -u "$user" - 2>/dev/null || true
        log "Removed PocketBase cron jobs for user: $user"
    fi
done

# 9. Remove PocketBase backup scripts
log "Removing PocketBase backup scripts..."
BACKUP_SCRIPTS=(
    "/usr/local/bin/backup-pocketbase"
    "/usr/local/bin/pocketbase-backup"
)

for script in "${BACKUP_SCRIPTS[@]}"; do
    if [[ -f "$script" ]]; then
        rm -f "$script"
        log "Removed backup script: $script"
    fi
done

# 10. Remove PocketBase logs
log "Removing PocketBase log files..."
LOG_LOCATIONS=(
    "/var/log/pocketbase"
    "/var/log/pocketbase.log"
)

for log_location in "${LOG_LOCATIONS[@]}"; do
    if [[ -e "$log_location" ]]; then
        rm -rf "$log_location"
        log "Removed logs: $log_location"
    fi
done

# 11. Remove PocketBase from logrotate
log "Removing PocketBase logrotate configuration..."
if [[ -f "/etc/logrotate.d/pocketbase" ]]; then
    rm -f "/etc/logrotate.d/pocketbase"
    log "Removed PocketBase logrotate configuration"
fi

# 12. Clean up any remaining PocketBase processes
log "Checking for running PocketBase processes..."
if pgrep -f "pocketbase" >/dev/null 2>&1; then
    warn "Found running PocketBase processes. Terminating..."
    pkill -f "pocketbase" || true
    sleep 2
    
    # Force kill if still running
    if pgrep -f "pocketbase" >/dev/null 2>&1; then
        pkill -9 -f "pocketbase" || true
        log "Force terminated PocketBase processes"
    fi
else
    log "No running PocketBase processes found"
fi

# 13. Remove PocketBase from PATH (if added)
log "Cleaning up PATH references..."
for profile_file in /etc/profile /etc/bash.bashrc /root/.bashrc /root/.profile; do
    if [[ -f "$profile_file" ]] && grep -q "pocketbase" "$profile_file"; then
        sed -i '/pocketbase/d' "$profile_file"
        log "Removed PocketBase PATH references from: $profile_file"
    fi
done

# 14. Remove any PocketBase-related environment files
log "Removing PocketBase environment files..."
ENV_FILES=(
    "/etc/environment.d/pocketbase.conf"
    "/etc/default/pocketbase"
)

for env_file in "${ENV_FILES[@]}"; do
    if [[ -f "$env_file" ]]; then
        rm -f "$env_file"
        log "Removed environment file: $env_file"
    fi
done

# 15. Clean up any remaining references in system files
log "Cleaning up system references..."

# Remove from /etc/hosts if added
if grep -q "pocketbase" /etc/hosts 2>/dev/null; then
    sed -i '/pocketbase/d' /etc/hosts
    log "Removed PocketBase entries from /etc/hosts"
fi

# 16. Restart affected services
log "Restarting affected services..."
if systemctl is-active --quiet nginx; then
    systemctl reload nginx
    log "Nginx reloaded"
fi

# 17. Final cleanup and verification
log "Performing final cleanup..."

# Remove any temporary files
find /tmp -name "*pocketbase*" -type f -mtime +1 -delete 2>/dev/null || true

# Clear systemd journal entries (optional)
journalctl --vacuum-time=1d >/dev/null 2>&1 || true

echo
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}    PocketBase Removal Complete!       ${NC}"
echo -e "${GREEN}========================================${NC}"
echo

log "PocketBase has been completely removed from your server."

# Show summary
echo -e "${BLUE}Removal Summary:${NC}"
echo "✓ PocketBase service stopped and disabled"
echo "✓ PocketBase binary and application files removed"
echo "✓ PocketBase user account removed"
echo "✓ PocketBase data directory handled"
echo "✓ Nginx configurations cleaned"
echo "✓ Cron jobs removed"
echo "✓ Log files cleaned"
echo "✓ System references removed"

if [[ -n "${BACKUP_DIR:-}" ]]; then
    echo
    warn "Don't forget: Your data backup is at $BACKUP_DIR"
    warn "Move it to a safe location if you need it later."
fi

echo
log "Your server is now ready for the new PostgreSQL-based system!"
echo