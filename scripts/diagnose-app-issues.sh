#!/bin/bash

# Diagnostic script for Member Management System issues
# Run this to identify and fix common application problems

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

APP_DIR="/opt/member-management"
APP_USER="memberapp"
DATA_DIR="/var/lib/member-management"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Member Management System Diagnostics ${NC}"
echo -e "${BLUE}========================================${NC}"
echo

log "Checking application directory structure..."
if [[ -d "$APP_DIR" ]]; then
    log "Application directory exists: $APP_DIR"
    ls -la "$APP_DIR"
else
    error "Application directory missing: $APP_DIR"
    exit 1
fi

echo

log "Checking for required application files..."
REQUIRED_FILES=(
    "server.js"
    "package.json"
    ".env"
)

MISSING_FILES=()
for file in "${REQUIRED_FILES[@]}"; do
    if [[ -f "$APP_DIR/$file" ]]; then
        log "✓ Found: $file"
    else
        error "✗ Missing: $file"
        MISSING_FILES+=("$file")
    fi
done

if [[ ${#MISSING_FILES[@]} -gt 0 ]]; then
    warn "Missing application files detected. Copying from project..."
    
    # Check if we're in the project directory
    if [[ -d "backend" ]]; then
        log "Copying backend files..."
        cp -r backend/* "$APP_DIR/"
        
        # Copy frontend files
        if [[ -d "frontend" ]]; then
            log "Copying frontend files..."
            mkdir -p "$APP_DIR/frontend"
            cp -r frontend/* "$APP_DIR/frontend/"
        fi
        
        # Set proper ownership
        chown -R "$APP_USER:$APP_USER" "$APP_DIR"
        log "Files copied and ownership set"
    else
        error "Backend directory not found. Please run this script from the project root."
        exit 1
    fi
fi

echo

log "Checking Node.js dependencies..."
if [[ -d "$APP_DIR/node_modules" ]]; then
    log "✓ Node modules directory exists"
else
    warn "Node modules missing. Installing dependencies..."
    cd "$APP_DIR"
    npm install
    chown -R "$APP_USER:$APP_USER" "$APP_DIR"
    log "Dependencies installed"
fi

echo

log "Checking environment configuration..."
if [[ -f "$APP_DIR/.env" ]]; then
    log "✓ Environment file exists"
    
    # Check for required environment variables
    REQUIRED_VARS=(
        "DB_HOST"
        "DB_NAME"
        "DB_USER"
        "DB_PASSWORD"
        "JWT_SECRET"
        "NODE_ENV"
    )
    
    for var in "${REQUIRED_VARS[@]}"; do
        if grep -q "^$var=" "$APP_DIR/.env"; then
            log "✓ $var is set"
        else
            warn "✗ $var is missing or not set"
        fi
    done
else
    error "Environment file missing: $APP_DIR/.env"
    exit 1
fi

echo

log "Testing database connection..."
DB_HOST=$(grep "^DB_HOST=" "$APP_DIR/.env" | cut -d'=' -f2)
DB_NAME=$(grep "^DB_NAME=" "$APP_DIR/.env" | cut -d'=' -f2)
DB_USER=$(grep "^DB_USER=" "$APP_DIR/.env" | cut -d'=' -f2)

if sudo -u postgres psql -h "$DB_HOST" -d "$DB_NAME" -U "$DB_USER" -c "SELECT 1;" > /dev/null 2>&1; then
    log "✓ Database connection successful"
else
    error "✗ Database connection failed"
    log "Checking PostgreSQL status..."
    systemctl status postgresql --no-pager -l
fi

echo

log "Testing application startup..."
cd "$APP_DIR"

# Try to start the application manually with timeout
log "Attempting to start application manually..."
timeout 10s sudo -u "$APP_USER" node server.js &
APP_PID=$!

sleep 5

if kill -0 $APP_PID 2>/dev/null; then
    log "✓ Application started successfully"
    kill $APP_PID 2>/dev/null || true
else
    error "✗ Application failed to start"
    log "Checking for detailed error output..."
    
    # Try to get more detailed error information
    log "Running application with detailed error output..."
    sudo -u "$APP_USER" timeout 5s node server.js || true
fi

echo

log "Checking service configuration..."
if [[ -f "/etc/systemd/system/member-management.service" ]]; then
    log "✓ Systemd service file exists"
    
    # Check service status
    if systemctl is-active --quiet member-management; then
        log "✓ Service is active"
    else
        warn "Service is not active"
        log "Service status:"
        systemctl status member-management --no-pager -l
    fi
else
    error "Systemd service file missing"
fi

echo

log "Checking recent service logs..."
log "Last 20 lines of service logs:"
journalctl -u member-management --no-pager -l -n 20

echo

log "Checking Nginx configuration..."
if nginx -t; then
    log "✓ Nginx configuration is valid"
else
    error "✗ Nginx configuration has errors"
fi

echo

log "Testing application endpoints..."
if curl -f -s --connect-timeout 5 http://127.0.0.1:3000/health > /dev/null 2>&1; then
    log "✓ Health endpoint responding"
else
    warn "Health endpoint not responding"
    
    # Check if port is listening
    if netstat -tlnp | grep -q ":3000"; then
        log "Port 3000 is listening"
    else
        warn "Port 3000 is not listening"
    fi
fi

echo

log "Diagnostic complete. Summary:"
echo "- Application directory: $([ -d "$APP_DIR" ] && echo "✓" || echo "✗")"
echo "- Required files: $([ ${#MISSING_FILES[@]} -eq 0 ] && echo "✓" || echo "✗")"
echo "- Node modules: $([ -d "$APP_DIR/node_modules" ] && echo "✓" || echo "✗")"
echo "- Environment config: $([ -f "$APP_DIR/.env" ] && echo "✓" || echo "✗")"
echo "- Database connection: $(sudo -u postgres psql -h localhost -d member_management -c "SELECT 1;" > /dev/null 2>&1 && echo "✓" || echo "✗")"
echo "- Service status: $(systemctl is-active --quiet member-management && echo "✓" || echo "✗")"

echo
log "If issues persist, check the detailed logs above and run:"
log "sudo journalctl -u member-management -f"