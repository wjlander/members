#!/bin/bash

# Nginx Configuration Cleanup Script
# Removes all existing configurations for p.ringing.org.uk and member.ringing.org.uk

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
echo -e "${BLUE}    Nginx Configuration Cleanup        ${NC}"
echo -e "${BLUE}========================================${NC}"
echo

log "Stopping Nginx service..."
systemctl stop nginx

log "Scanning for conflicting configurations..."

# Function to search for domain references in files
search_domain_configs() {
    local domain=$1
    log "Searching for configurations containing: $domain"
    
    # Search in sites-available
    if [[ -d "/etc/nginx/sites-available" ]]; then
        for file in /etc/nginx/sites-available/*; do
            if [[ -f "$file" ]] && grep -q "$domain" "$file" 2>/dev/null; then
                warn "Found $domain in: $file"
                echo "  Content preview:"
                grep -n "$domain" "$file" | head -3 | sed 's/^/    /'
                echo
            fi
        done
    fi
    
    # Search in sites-enabled
    if [[ -d "/etc/nginx/sites-enabled" ]]; then
        for file in /etc/nginx/sites-enabled/*; do
            if [[ -f "$file" ]] && grep -q "$domain" "$file" 2>/dev/null; then
                warn "Found $domain in: $file"
                echo "  Content preview:"
                grep -n "$domain" "$file" | head -3 | sed 's/^/    /'
                echo
            fi
        done
    fi
    
    # Search in main nginx.conf
    if grep -q "$domain" /etc/nginx/nginx.conf 2>/dev/null; then
        warn "Found $domain in: /etc/nginx/nginx.conf"
        echo "  Content preview:"
        grep -n "$domain" /etc/nginx/nginx.conf | sed 's/^/    /'
        echo
    fi
    
    # Search in conf.d directory
    if [[ -d "/etc/nginx/conf.d" ]]; then
        for file in /etc/nginx/conf.d/*; do
            if [[ -f "$file" ]] && grep -q "$domain" "$file" 2>/dev/null; then
                warn "Found $domain in: $file"
                echo "  Content preview:"
                grep -n "$domain" "$file" | head -3 | sed 's/^/    /'
                echo
            fi
        done
    fi
}

# Search for both domains
search_domain_configs "p.ringing.org.uk"
search_domain_configs "member.ringing.org.uk"

log "Listing all current Nginx site configurations..."
echo "Sites available:"
ls -la /etc/nginx/sites-available/ 2>/dev/null || echo "  No sites-available directory"
echo
echo "Sites enabled:"
ls -la /etc/nginx/sites-enabled/ 2>/dev/null || echo "  No sites-enabled directory"
echo

# Remove all configurations containing our domains
log "Removing configurations containing our domains..."

# Function to remove files containing domain
remove_domain_configs() {
    local domain=$1
    local removed_count=0
    
    # Remove from sites-available
    if [[ -d "/etc/nginx/sites-available" ]]; then
        for file in /etc/nginx/sites-available/*; do
            if [[ -f "$file" ]] && grep -q "$domain" "$file" 2>/dev/null; then
                log "Removing sites-available file: $(basename "$file")"
                rm -f "$file"
                ((removed_count++))
            fi
        done
    fi
    
    # Remove from sites-enabled
    if [[ -d "/etc/nginx/sites-enabled" ]]; then
        for file in /etc/nginx/sites-enabled/*; do
            if [[ -f "$file" ]] && grep -q "$domain" "$file" 2>/dev/null; then
                log "Removing sites-enabled file: $(basename "$file")"
                rm -f "$file"
                ((removed_count++))
            fi
        done
    fi
    
    # Remove from conf.d
    if [[ -d "/etc/nginx/conf.d" ]]; then
        for file in /etc/nginx/conf.d/*; do
            if [[ -f "$file" ]] && grep -q "$domain" "$file" 2>/dev/null; then
                log "Removing conf.d file: $(basename "$file")"
                rm -f "$file"
                ((removed_count++))
            fi
        done
    fi
    
    return $removed_count
}

# Remove configurations for both domains
remove_domain_configs "p.ringing.org.uk"
remove_domain_configs "member.ringing.org.uk"

# Also remove common configuration file names that might exist
COMMON_CONFIG_NAMES=(
    "member-management"
    "member-ringing"
    "admin-ringing"
    "pocketbase"
    "ringing"
    "member.ringing.org.uk"
    "p.ringing.org.uk"
)

log "Removing common configuration file names..."
for config_name in "${COMMON_CONFIG_NAMES[@]}"; do
    if [[ -f "/etc/nginx/sites-available/$config_name" ]]; then
        log "Removing sites-available/$config_name"
        rm -f "/etc/nginx/sites-available/$config_name"
    fi
    
    if [[ -f "/etc/nginx/sites-enabled/$config_name" ]]; then
        log "Removing sites-enabled/$config_name"
        rm -f "/etc/nginx/sites-enabled/$config_name"
    fi
    
    if [[ -f "/etc/nginx/conf.d/$config_name.conf" ]]; then
        log "Removing conf.d/$config_name.conf"
        rm -f "/etc/nginx/conf.d/$config_name.conf"
    fi
done

# Remove default site if it exists and might be conflicting
if [[ -f "/etc/nginx/sites-enabled/default" ]]; then
    log "Removing default site configuration"
    rm -f "/etc/nginx/sites-enabled/default"
fi

log "Cleaning up any backup files..."
find /etc/nginx -name "*.backup" -delete 2>/dev/null || true
find /etc/nginx -name "*.bak" -delete 2>/dev/null || true
find /etc/nginx -name "*~" -delete 2>/dev/null || true

log "Final verification - checking for any remaining domain references..."
REMAINING_REFS=0

# Check for any remaining references
for domain in "p.ringing.org.uk" "member.ringing.org.uk"; do
    if grep -r "$domain" /etc/nginx/ 2>/dev/null; then
        warn "Still found references to $domain:"
        grep -r "$domain" /etc/nginx/ 2>/dev/null | sed 's/^/    /'
        ((REMAINING_REFS++))
    fi
done

if [[ $REMAINING_REFS -eq 0 ]]; then
    log "✓ No remaining domain references found"
else
    warn "⚠ Found $REMAINING_REFS remaining domain references"
fi

log "Testing Nginx configuration..."
if nginx -t; then
    log "✓ Nginx configuration test passed"
    
    log "Starting Nginx service..."
    systemctl start nginx
    
    if systemctl is-active --quiet nginx; then
        log "✓ Nginx started successfully"
    else
        error "✗ Nginx failed to start"
        systemctl status nginx
    fi
else
    error "✗ Nginx configuration test failed"
    nginx -t
    exit 1
fi

echo
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}         Cleanup Complete!              ${NC}"
echo -e "${GREEN}========================================${NC}"
echo
log "All conflicting configurations have been removed"
log "Nginx is now running with a clean configuration"
log "You can now run your deployment script again"
echo
log "Current Nginx sites:"
echo "Sites available:"
ls -la /etc/nginx/sites-available/ 2>/dev/null || echo "  (empty)"
echo "Sites enabled:"
ls -la /etc/nginx/sites-enabled/ 2>/dev/null || echo "  (empty)"