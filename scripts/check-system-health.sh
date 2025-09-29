#!/bin/bash

# System Health Check Script
# Checks if the Member Management System is working properly

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

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

APP_DIR="/opt/member-management"
APP_USER="memberapp"
DATA_DIR="/var/lib/member-management"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Member Management System Health Check ${NC}"
echo -e "${BLUE}========================================${NC}"
echo

# Check 1: Service Status
log "Checking service status..."
if systemctl is-active --quiet member-management; then
    success "✓ Member Management service is running"
    SERVICE_STATUS="running"
else
    error "✗ Member Management service is not running"
    SERVICE_STATUS="stopped"
    systemctl status member-management --no-pager -l
fi

echo

# Check 2: Database Connection
log "Checking database connection..."
if sudo -u postgres psql -d member_management -c "SELECT 1;" > /dev/null 2>&1; then
    success "✓ Database connection successful"
    DB_STATUS="connected"
else
    error "✗ Database connection failed"
    DB_STATUS="failed"
fi

echo

# Check 3: Application Response
log "Checking application endpoints..."
if curl -f -s --connect-timeout 10 http://127.0.0.1:3000/health > /dev/null 2>&1; then
    success "✓ Application health endpoint responding"
    APP_STATUS="responding"
    
    # Get health check details
    HEALTH_RESPONSE=$(curl -s http://127.0.0.1:3000/health 2>/dev/null || echo "No response")
    log "Health check response: $HEALTH_RESPONSE"
else
    error "✗ Application health endpoint not responding"
    APP_STATUS="not_responding"
    
    # Check if port is listening
    if netstat -tlnp | grep -q ":3000"; then
        warn "Port 3000 is listening but not responding to HTTP requests"
    else
        warn "Port 3000 is not listening"
    fi
fi

echo

# Check 4: Nginx Status
log "Checking Nginx status..."
if systemctl is-active --quiet nginx; then
    success "✓ Nginx is running"
    NGINX_STATUS="running"
    
    # Test Nginx configuration
    if nginx -t > /dev/null 2>&1; then
        success "✓ Nginx configuration is valid"
    else
        warn "⚠ Nginx configuration has issues"
        nginx -t
    fi
else
    error "✗ Nginx is not running"
    NGINX_STATUS="stopped"
fi

echo

# Check 5: SSL Certificates
log "Checking SSL certificates..."
if [[ -f "/etc/letsencrypt/live/member.ringing.org.uk/cert.pem" ]]; then
    CERT_EXPIRY=$(openssl x509 -enddate -noout -in /etc/letsencrypt/live/member.ringing.org.uk/cert.pem | cut -d= -f2)
    success "✓ SSL certificate exists"
    log "Certificate expires: $CERT_EXPIRY"
    SSL_STATUS="valid"
else
    warn "⚠ SSL certificate not found"
    SSL_STATUS="missing"
fi

echo

# Check 6: External Access
log "Checking external domain access..."
if curl -I -s --connect-timeout 10 https://member.ringing.org.uk > /dev/null 2>&1; then
    success "✓ Main domain (member.ringing.org.uk) is accessible"
    MAIN_DOMAIN_STATUS="accessible"
else
    warn "⚠ Main domain (member.ringing.org.uk) is not accessible"
    MAIN_DOMAIN_STATUS="not_accessible"
fi

if curl -I -s --connect-timeout 10 https://p.ringing.org.uk > /dev/null 2>&1; then
    success "✓ Admin domain (p.ringing.org.uk) is accessible"
    ADMIN_DOMAIN_STATUS="accessible"
else
    warn "⚠ Admin domain (p.ringing.org.uk) is not accessible"
    ADMIN_DOMAIN_STATUS="not_accessible"
fi

echo

# Check 7: Recent Logs
log "Checking recent application logs..."
if journalctl -u member-management --since "5 minutes ago" --no-pager -q; then
    log "Recent logs (last 5 minutes):"
    journalctl -u member-management --since "5 minutes ago" --no-pager -n 10
else
    warn "No recent logs found"
fi

echo

# Check 8: File System
log "Checking file system..."
if [[ -f "$APP_DIR/server.js" ]]; then
    success "✓ Application files exist"
    FILES_STATUS="present"
else
    error "✗ Application files missing"
    FILES_STATUS="missing"
fi

if [[ -f "$APP_DIR/.env" ]]; then
    success "✓ Environment configuration exists"
    ENV_STATUS="present"
else
    error "✗ Environment configuration missing"
    ENV_STATUS="missing"
fi

echo

# Summary
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}           HEALTH CHECK SUMMARY         ${NC}"
echo -e "${BLUE}========================================${NC}"

echo "Service Status:      $([ "$SERVICE_STATUS" = "running" ] && echo "✓ Running" || echo "✗ Stopped")"
echo "Database:            $([ "$DB_STATUS" = "connected" ] && echo "✓ Connected" || echo "✗ Failed")"
echo "Application:         $([ "$APP_STATUS" = "responding" ] && echo "✓ Responding" || echo "✗ Not Responding")"
echo "Nginx:               $([ "$NGINX_STATUS" = "running" ] && echo "✓ Running" || echo "✗ Stopped")"
echo "SSL Certificate:     $([ "$SSL_STATUS" = "valid" ] && echo "✓ Valid" || echo "⚠ Missing")"
echo "Main Domain:         $([ "$MAIN_DOMAIN_STATUS" = "accessible" ] && echo "✓ Accessible" || echo "⚠ Not Accessible")"
echo "Admin Domain:        $([ "$ADMIN_DOMAIN_STATUS" = "accessible" ] && echo "✓ Accessible" || echo "⚠ Not Accessible")"
echo "Application Files:   $([ "$FILES_STATUS" = "present" ] && echo "✓ Present" || echo "✗ Missing")"
echo "Environment Config:  $([ "$ENV_STATUS" = "present" ] && echo "✓ Present" || echo "✗ Missing")"

echo

# Overall status
ISSUES=0
[ "$SERVICE_STATUS" != "running" ] && ((ISSUES++))
[ "$DB_STATUS" != "connected" ] && ((ISSUES++))
[ "$APP_STATUS" != "responding" ] && ((ISSUES++))
[ "$NGINX_STATUS" != "running" ] && ((ISSUES++))
[ "$FILES_STATUS" != "present" ] && ((ISSUES++))
[ "$ENV_STATUS" != "present" ] && ((ISSUES++))

if [ $ISSUES -eq 0 ]; then
    success "🎉 System is healthy! All checks passed."
    echo
    log "You can access the system at:"
    log "- Main site: https://member.ringing.org.uk"
    log "- Admin site: https://p.ringing.org.uk"
else
    warn "⚠ Found $ISSUES issue(s) that need attention."
    echo
    log "To troubleshoot issues, you can:"
    log "- Check service logs: sudo journalctl -u member-management -f"
    log "- Check Nginx logs: sudo tail -f /var/log/nginx/error.log"
    log "- Run diagnostics: sudo bash scripts/diagnose-app-issues.sh"
fi

echo