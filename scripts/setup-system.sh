#!/bin/bash

# Initial System Setup Script
# Run this to complete the initial setup of your Member Management System

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

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Member Management System Setup        ${NC}"
echo -e "${BLUE}========================================${NC}"
echo

log "Starting initial system setup..."

# Step 1: Check if database is accessible
log "Checking database connection..."
if sudo -u postgres psql -d member_management -c "SELECT 1;" > /dev/null 2>&1; then
    log "✓ Database connection successful"
else
    error "✗ Database connection failed. Please check PostgreSQL service."
    exit 1
fi

# Step 2: Check if tables exist
log "Checking database schema..."
TABLE_COUNT=$(sudo -u postgres psql -d member_management -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" | xargs)

if [ "$TABLE_COUNT" -gt 0 ]; then
    log "✓ Database schema exists ($TABLE_COUNT tables found)"
else
    warn "⚠ Database schema not found. Running migrations..."
    
    # Run migrations if they exist
    if [ -d "supabase/migrations" ]; then
        for migration in supabase/migrations/*.sql; do
            if [ -f "$migration" ]; then
                log "Running migration: $(basename "$migration")"
                sudo -u postgres psql -d member_management -f "$migration"
            fi
        done
    else
        error "Migration files not found. Please ensure the database schema is set up."
        exit 1
    fi
fi

# Step 3: Check if admin user exists
log "Checking for existing admin users..."
ADMIN_COUNT=$(sudo -u postgres psql -d member_management -t -c "SELECT COUNT(*) FROM users WHERE role IN ('admin', 'super_admin');" | xargs)

if [ "$ADMIN_COUNT" -gt 0 ]; then
    log "✓ Admin user(s) already exist ($ADMIN_COUNT found)"
    
    log "Existing admin users:"
    sudo -u postgres psql -d member_management -c "SELECT email, name, role FROM users WHERE role IN ('admin', 'super_admin');"
else
    warn "⚠ No admin users found. You need to create one."
    echo
    echo "To create your first admin user, you have two options:"
    echo
    echo "Option 1: Use the SQL script"
    echo "  1. Edit scripts/create-first-admin.sql"
    echo "  2. Change the email and password"
    echo "  3. Run: sudo -u postgres psql -d member_management -f scripts/create-first-admin.sql"
    echo
    echo "Option 2: Create manually via psql"
    echo "  sudo -u postgres psql -d member_management"
    echo "  Then run the SQL commands to create user and member records"
    echo
fi

# Step 4: Check application service
log "Checking application service..."
if systemctl is-active --quiet member-management; then
    log "✓ Member Management service is running"
else
    warn "⚠ Member Management service is not running"
    log "Starting service..."
    sudo systemctl start member-management
    
    sleep 5
    
    if systemctl is-active --quiet member-management; then
        log "✓ Service started successfully"
    else
        error "✗ Failed to start service. Check logs: sudo journalctl -u member-management -f"
    fi
fi

# Step 5: Test application endpoints
log "Testing application endpoints..."
if curl -f -s --connect-timeout 10 http://127.0.0.1:3000/health > /dev/null 2>&1; then
    log "✓ Application is responding"
    
    # Get health response
    HEALTH_RESPONSE=$(curl -s http://127.0.0.1:3000/health 2>/dev/null)
    log "Health check: $HEALTH_RESPONSE"
else
    warn "⚠ Application health check failed"
fi

# Step 6: Check web access
log "Checking web access..."
if curl -I -s --connect-timeout 10 https://member.ringing.org.uk > /dev/null 2>&1; then
    log "✓ Main domain accessible: https://member.ringing.org.uk"
else
    warn "⚠ Main domain not accessible externally"
fi

if curl -I -s --connect-timeout 10 https://p.ringing.org.uk > /dev/null 2>&1; then
    log "✓ Admin domain accessible: https://p.ringing.org.uk"
else
    warn "⚠ Admin domain not accessible externally"
fi

echo
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}           SETUP SUMMARY                ${NC}"
echo -e "${BLUE}========================================${NC}"

echo "Database:        $([ "$TABLE_COUNT" -gt 0 ] && echo "✓ Ready" || echo "✗ Needs Setup")"
echo "Admin Users:     $([ "$ADMIN_COUNT" -gt 0 ] && echo "✓ $ADMIN_COUNT found" || echo "✗ None - Create First Admin")"
echo "Service:         $(systemctl is-active --quiet member-management && echo "✓ Running" || echo "✗ Stopped")"
echo "Web Access:      $(curl -I -s --connect-timeout 5 https://member.ringing.org.uk > /dev/null 2>&1 && echo "✓ Available" || echo "⚠ Check DNS/SSL")"

echo
if [ "$ADMIN_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}NEXT STEPS:${NC}"
    echo "1. Create your first admin user using scripts/create-first-admin.sql"
    echo "2. Access the system at https://member.ringing.org.uk"
    echo "3. Login with your admin credentials"
    echo "4. Configure your association settings"
    echo "5. Set up email integration (optional)"
else
    echo -e "${GREEN}SYSTEM READY!${NC}"
    echo "✓ Access your system at: https://member.ringing.org.uk"
    echo "✓ Admin panel at: https://p.ringing.org.uk"
    echo "✓ Login with your existing admin credentials"
fi

echo