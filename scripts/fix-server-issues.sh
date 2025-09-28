#!/bin/bash

# Fix server startup issues and port conflicts

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

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Fixing Server Issues                  ${NC}"
echo -e "${BLUE}========================================${NC}"
echo

log "Stopping member-management service..."
systemctl stop member-management || true

log "Checking for processes using port 3000..."
if netstat -tlnp | grep -q ":3000"; then
    warn "Found processes using port 3000:"
    netstat -tlnp | grep ":3000"
    
    # Kill any processes using port 3000
    log "Killing processes using port 3000..."
    lsof -ti:3000 | xargs kill -9 2>/dev/null || true
    sleep 2
    
    if netstat -tlnp | grep -q ":3000"; then
        error "Port 3000 is still in use after cleanup"
        netstat -tlnp | grep ":3000"
    else
        log "✓ Port 3000 is now free"
    fi
else
    log "✓ Port 3000 is available"
fi

log "Checking if backend files exist in current directory..."
if [[ ! -d "backend" ]]; then
    error "Backend directory not found. Please run this script from the project root directory."
    exit 1
fi

log "Copying backend files to application directory..."
cp -r backend/* "$APP_DIR/"

log "Copying frontend files..."
if [[ -d "frontend" ]]; then
    mkdir -p "$APP_DIR/frontend"
    cp -r frontend/* "$APP_DIR/frontend/"
else
    warn "Frontend directory not found, skipping frontend files"
fi

log "Setting proper ownership..."
chown -R "$APP_USER:$APP_USER" "$APP_DIR"

log "Installing/updating Node.js dependencies..."
cd "$APP_DIR"
npm install

log "Verifying server.js exists..."
if [[ -f "$APP_DIR/server.js" ]]; then
    log "✓ server.js found"
else
    error "✗ server.js still missing after copy"
    exit 1
fi

log "Testing application startup manually..."
cd "$APP_DIR"
timeout 10s sudo -u "$APP_USER" node server.js &
TEST_PID=$!

sleep 5

if kill -0 $TEST_PID 2>/dev/null; then
    log "✓ Application started successfully"
    kill $TEST_PID 2>/dev/null || true
    wait $TEST_PID 2>/dev/null || true
else
    warn "Application test startup failed or timed out"
fi

log "Starting member-management service..."
systemctl start member-management

sleep 5

log "Checking service status..."
if systemctl is-active --quiet member-management; then
    log "✓ Service is running"
else
    error "✗ Service failed to start"
    log "Recent service logs:"
    journalctl -u member-management --no-pager -l -n 10
    exit 1
fi

log "Testing application endpoints..."
sleep 3
if curl -f -s --connect-timeout 10 http://127.0.0.1:3000/health > /dev/null 2>&1; then
    log "✓ Application is responding"
else
    warn "Application health check failed"
    log "Checking what's listening on port 3000:"
    netstat -tlnp | grep ":3000" || log "Nothing listening on port 3000"
fi

echo
log "Server issues fixed! The application should now be working."
log "Check the websites:"
log "- Main site: https://member.ringing.org.uk"
log "- Admin site: https://p.ringing.org.uk"