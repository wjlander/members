#!/bin/bash

# Member Management System - Automated Deployment Script
# Compatible with Debian 11+ and Ubuntu 20.04+
# Run as root or with sudo privileges

set -e  # Exit on any error

# Configuration
POCKETBASE_VERSION="0.30.0"
APP_USER="pocketbase"
APP_DIR="/opt/member-management"
DATA_DIR="/var/lib/pocketbase"
NGINX_SITE="member-management"
MAIN_DOMAIN=""
ADMIN_DOMAIN=""

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
    exit 1
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root or with sudo privileges"
fi

# Get domain from user
get_domain() {
    # Set default domains
    MAIN_DOMAIN="member.ringing.org.uk"
    ADMIN_DOMAIN="p.ringing.org.uk"
    
    echo -e "${BLUE}Using domains:${NC}"
    echo "Main system: $MAIN_DOMAIN"
    echo "Admin panel: $ADMIN_DOMAIN"
    
    read -p "Press Enter to continue or type 'custom' to use different domains: " choice
    
    if [[ "$choice" == "custom" ]]; then
        while [[ -z "$MAIN_DOMAIN" ]]; do
            read -p "Enter main domain (e.g., member.yourorg.com): " MAIN_DOMAIN
            if [[ ! "$MAIN_DOMAIN" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
                echo "Invalid domain format. Please try again."
                MAIN_DOMAIN=""
            fi
        done
        
        while [[ -z "$ADMIN_DOMAIN" ]]; do
            read -p "Enter admin domain (e.g., admin.yourorg.com): " ADMIN_DOMAIN
            if [[ ! "$ADMIN_DOMAIN" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
                echo "Invalid domain format. Please try again."
                ADMIN_DOMAIN=""
            fi
        done
    fi
    
    echo -e "${BLUE}Domains configured:${NC}"
    echo "Main system: $MAIN_DOMAIN"
    echo "Admin panel: $ADMIN_DOMAIN"
}

# System update and dependency installation
install_dependencies() {
    log "Updating system packages..."
    apt-get update
    apt-get upgrade -y

    log "Installing dependencies..."
    apt-get install -y \
        curl \
        wget \
        unzip \
        nginx \
        certbot \
        python3-certbot-nginx \
        ufw \
        htop \
        fail2ban \
        logrotate
}

# Remove existing PocketBase installation
remove_existing_installation() {
    log "Checking for existing PocketBase installation..."
    
    # Stop services if running
    if systemctl is-active --quiet pocketbase; then
        warn "Stopping existing PocketBase service..."
        systemctl stop pocketbase
        systemctl disable pocketbase
    fi
    
    # Remove service file
    if [[ -f "/etc/systemd/system/pocketbase.service" ]]; then
        rm -f /etc/systemd/system/pocketbase.service
        systemctl daemon-reload
    fi
    
    # Remove application directory but preserve data
    if [[ -d "$APP_DIR" ]]; then
        warn "Removing existing application directory..."
        rm -rf "$APP_DIR"
    fi
    
    # Remove nginx configuration
    if [[ -f "/etc/nginx/sites-available/$NGINX_SITE" ]]; then
        rm -f "/etc/nginx/sites-available/$NGINX_SITE"
        rm -f "/etc/nginx/sites-enabled/$NGINX_SITE"
    fi
}

# Create application user and directories
setup_user_and_directories() {
    log "Creating application user and directories..."
    
    # Remove existing user if it exists (to ensure clean setup)
    if id "$APP_USER" &>/dev/null; then
        warn "Removing existing $APP_USER user..."
        userdel -r "$APP_USER" 2>/dev/null || true
    fi
    
    # Create fresh user with proper settings
    useradd --system --shell /bin/false --home-dir "$DATA_DIR" --create-home "$APP_USER"
    
    # Verify user was created
    if ! id "$APP_USER" &>/dev/null; then
        error "Failed to create user $APP_USER"
    fi
    
    # Create directories
    mkdir -p "$APP_DIR"
    mkdir -p "$DATA_DIR"
    mkdir -p "$DATA_DIR/backups"
    mkdir -p "/var/log/pocketbase"
    
    # Set proper ownership and permissions for directories
    chown -R "$APP_USER:$APP_USER" "$DATA_DIR"
    chown -R "$APP_USER:$APP_USER" "/var/log/pocketbase"
    chmod 755 "$DATA_DIR"
    chmod 755 "/var/log/pocketbase"
    chmod 755 "$APP_DIR"
    
    # Verify permissions
    log "Verifying user and permissions..."
    ls -la "$APP_DIR/"
    ls -la "$DATA_DIR/"
    id "$APP_USER"
}

# Download and install PocketBase
install_pocketbase() {
    log "Downloading PocketBase v$POCKETBASE_VERSION..."
    
    # Detect architecture
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) ARCH_SUFFIX="linux_amd64" ;;
        aarch64|arm64) ARCH_SUFFIX="linux_arm64" ;;
        *) error "Unsupported architecture: $ARCH" ;;
    esac
    
    # Download PocketBase
    cd /tmp
    wget -O pocketbase.zip "https://github.com/pocketbase/pocketbase/releases/download/v$POCKETBASE_VERSION/pocketbase_${POCKETBASE_VERSION}_${ARCH_SUFFIX}.zip"
    
    # Extract and install
    unzip -o pocketbase.zip
    
    # Verify binary exists and is executable
    if [[ ! -f "pocketbase" ]]; then
        error "PocketBase binary not found after extraction"
    fi
    
    mv pocketbase "$APP_DIR/"
    chmod +x "$APP_DIR/pocketbase"
    
    # Cleanup
    rm -f pocketbase.zip LICENSE.md
    
    # Test PocketBase binary
    log "Testing PocketBase binary..."
    if ! "$APP_DIR/pocketbase" --help >/dev/null 2>&1; then
        error "PocketBase binary is not working correctly"
    fi
    
    log "PocketBase installed successfully"
}

# Create systemd service
create_systemd_service() {
    log "Creating systemd service..."
    
    cat > "/etc/systemd/system/pocketbase.service" << EOF
[Unit]
Description=PocketBase Member Management System
After=network.target
Wants=network.target

[Service]
Type=simple
User=$APP_USER
Group=$APP_USER
ExecStart=$APP_DIR/pocketbase serve --http=127.0.0.1:8090 --dir=$DATA_DIR
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$DATA_DIR /var/log/pocketbase

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable pocketbase
}

# Configure Nginx
configure_nginx() {
    log "Configuring Nginx..."
    
    # Start Nginx if not running
    if ! systemctl is-active --quiet nginx; then
        systemctl start nginx
    fi
    
    # Backup default config
    if [[ -f "/etc/nginx/sites-enabled/default" ]]; then
        mv "/etc/nginx/sites-enabled/default" "/etc/nginx/sites-enabled/default.bak"
    fi
    
    # Remove any existing configurations that might conflict
    rm -f /etc/nginx/sites-available/member-ringing
    rm -f /etc/nginx/sites-available/admin-ringing
    rm -f /etc/nginx/sites-enabled/member-ringing
    rm -f /etc/nginx/sites-enabled/admin-ringing
    
    # Create main site configuration
    cat > "/etc/nginx/sites-available/member-ringing" << EOF
server {
    listen 80;
    server_name $MAIN_DOMAIN;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    
    # File upload size limit
    client_max_body_size 100M;
    
    location / {
        proxy_pass http://127.0.0.1:8090;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_cache_bypass \$http_upgrade;
    }
    
    # Serve static files from PocketBase
    location /api/files/ {
        proxy_pass http://127.0.0.1:8090;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # API access
    location /api/ {
        proxy_pass http://127.0.0.1:8090;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
    
    # Create admin site configuration
    cat > "/etc/nginx/sites-available/admin-ringing" << EOF
server {
    listen 80;
    server_name $ADMIN_DOMAIN;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    
    # File upload size limit
    client_max_body_size 100M;
    
    # Admin panel access
    location /_/ {
        proxy_pass http://127.0.0.1:8090;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_cache_bypass \$http_upgrade;
    }
    
    # API access for admin
    location /api/ {
        proxy_pass http://127.0.0.1:8090;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # Redirect root to admin panel
    location = / {
        return 301 \$scheme://\$host/_/;
    }
    
    # Serve static files for admin
    location /api/files/ {
        proxy_pass http://127.0.0.1:8090;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

    # Enable both sites
    ln -sf "/etc/nginx/sites-available/member-ringing" "/etc/nginx/sites-enabled/"
    ln -sf "/etc/nginx/sites-available/admin-ringing" "/etc/nginx/sites-enabled/"
    
    nginx -t || error "Nginx configuration test failed"
    
    systemctl restart nginx
}

# Setup SSL certificate
setup_ssl() {
    log "Setting up SSL certificate with Let's Encrypt..."
    
    # Test if domain points to this server
    PUBLIC_IP=$(curl -s ipecho.net/plain || curl -s icanhazip.com)
    MAIN_DOMAIN_IP=$(dig +short "$MAIN_DOMAIN" | head -n1)
    ADMIN_DOMAIN_IP=$(dig +short "$ADMIN_DOMAIN" | head -n1)
    
    if [[ "$PUBLIC_IP" != "$MAIN_DOMAIN_IP" ]] || [[ "$PUBLIC_IP" != "$ADMIN_DOMAIN_IP" ]]; then
        warn "One or both domains do not point to this server"
        warn "Main domain $MAIN_DOMAIN: $MAIN_DOMAIN_IP (should be $PUBLIC_IP)"
        warn "Admin domain $ADMIN_DOMAIN: $ADMIN_DOMAIN_IP (should be $PUBLIC_IP)"
        warn "SSL certificate setup skipped. Please configure DNS and run:"
        warn "certbot --nginx -d $MAIN_DOMAIN -d $ADMIN_DOMAIN"
        return
    fi
    
    # Setup SSL for both domains
    certbot --nginx --non-interactive --agree-tos --register-unsafely-without-email -d "$MAIN_DOMAIN" -d "$ADMIN_DOMAIN"
    
    # Setup auto-renewal
    systemctl enable certbot.timer
    systemctl start certbot.timer
}

# Configure firewall
configure_firewall() {
    log "Configuring firewall..."
    
    # Reset UFW to defaults
    ufw --force reset
    
    # Default policies
    ufw default deny incoming
    ufw default allow outgoing
    
    # Allow SSH, HTTP, HTTPS
    ufw allow ssh
    ufw allow 'Nginx Full'
    
    # Enable firewall
    ufw --force enable
    
    log "Firewall configured successfully"
}

# Setup fail2ban
setup_fail2ban() {
    log "Configuring fail2ban..."
    
    cat > "/etc/fail2ban/jail.local" << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s

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
EOF

    systemctl restart fail2ban
    systemctl enable fail2ban
}

# Create backup script
create_backup_script() {
    log "Creating backup script..."
    
    cat > "/usr/local/bin/backup-pocketbase" << 'EOF'
#!/bin/bash

BACKUP_DIR="/var/lib/pocketbase/backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/pocketbase_backup_$DATE.tar.gz"

# Create backup
tar -czf "$BACKUP_FILE" -C /var/lib/pocketbase pb_data pb_migrations

# Keep only last 7 backups
cd "$BACKUP_DIR"
ls -t pocketbase_backup_*.tar.gz | tail -n +8 | xargs rm -f

echo "Backup created: $BACKUP_FILE"
EOF

    chmod +x "/usr/local/bin/backup-pocketbase"
    
    # Setup daily backup cron job
    cat > "/etc/cron.daily/pocketbase-backup" << 'EOF'
#!/bin/bash
/usr/local/bin/backup-pocketbase >> /var/log/pocketbase/backup.log 2>&1
EOF

    chmod +x "/etc/cron.daily/pocketbase-backup"
}

# Setup log rotation
setup_log_rotation() {
    log "Setting up log rotation..."
    
    cat > "/etc/logrotate.d/pocketbase" << EOF
/var/log/pocketbase/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 644 $APP_USER $APP_USER
    postrotate
        systemctl reload pocketbase
    endscript
}
EOF
}

# Initialize PocketBase with schema
initialize_pocketbase() {
    log "Starting PocketBase and initializing schema..."
    
    # Final permission check before starting
    chown -R "$APP_USER:$APP_USER" "$DATA_DIR"
    chown -R "$APP_USER:$APP_USER" "/var/log/pocketbase"
    chown "$APP_USER:$APP_USER" "$APP_DIR/pocketbase"
    chmod +x "$APP_DIR/pocketbase"
    
    # Test if we can run PocketBase as the user
    log "Testing PocketBase execution as $APP_USER..."
    if ! sudo -u "$APP_USER" "$APP_DIR/pocketbase" --help >/dev/null 2>&1; then
        error "Cannot execute PocketBase as user $APP_USER"
    fi
    
    # Ensure PocketBase service is enabled and started
    systemctl enable pocketbase
    systemctl start pocketbase
    
    # Wait for PocketBase to start
    sleep 10
    
    # Check multiple times if needed
    for i in {1..5}; do
        if systemctl is-active --quiet pocketbase; then
            break
        fi
        log "Waiting for PocketBase to start (attempt $i/5)..."
        # Show recent logs for debugging
        journalctl -u pocketbase --no-pager -l -n 10
        sleep 5
    done
    
    # Check if PocketBase is running
    if ! systemctl is-active --quiet pocketbase; then
        error_log=$(journalctl -u pocketbase --no-pager -l -n 20)
        log "Recent PocketBase logs:"
        echo "$error_log"
        error "PocketBase failed to start. Check logs: journalctl -u pocketbase"
    fi
    
    # Test if PocketBase is responding
    for i in {1..10}; do
        if curl -s http://127.0.0.1:8090/api/health >/dev/null 2>&1; then
            log "PocketBase is responding to API requests"
            break
        fi
        log "Waiting for PocketBase API to be ready (attempt $i/10)..."
        sleep 3
    done
    
    log "PocketBase started successfully"
    log "Local admin panel available at: http://127.0.0.1:8090/_/"
}

# Create initial configuration file
create_config_file() {
    log "Creating configuration documentation..."
    
    cat > "$APP_DIR/SETUP_INFO.md" << EOF
# PocketBase Member Management System - Setup Information

## Installation Details
- Installation Date: $(date)
- Main Domain: $MAIN_DOMAIN
- Admin Domain: $ADMIN_DOMAIN
- PocketBase Version: $POCKETBASE_VERSION
- Data Directory: $DATA_DIR
- Application Directory: $APP_DIR

## Important URLs
- Main System: https://$MAIN_DOMAIN/
- Admin Panel: https://$ADMIN_DOMAIN/_/
- API Base URL: https://$MAIN_DOMAIN/api/

## Service Management
\`\`\`bash
# Start service
sudo systemctl start pocketbase

# Stop service
sudo systemctl stop pocketbase

# Restart service
sudo systemctl restart pocketbase

# View logs
sudo journalctl -u pocketbase -f
\`\`\`

## Backup and Restore
\`\`\`bash
# Manual backup
sudo /usr/local/bin/backup-pocketbase

# List backups
ls -la $DATA_DIR/backups/

# Restore from backup (stop service first)
sudo systemctl stop pocketbase
cd $DATA_DIR
sudo tar -xzf backups/pocketbase_backup_YYYYMMDD_HHMMSS.tar.gz
sudo systemctl start pocketbase
\`\`\`

## Next Steps
1. Access the admin panel at https://$ADMIN_DOMAIN/_/
2. Create your first admin user
3. Import the database schema from the web interface
4. Configure your associations and member settings

## Support Files Location
- Application: $APP_DIR
- Data: $DATA_DIR
- Logs: /var/log/pocketbase/
- Configuration: This file
EOF

    chown "$APP_USER:$APP_USER" "$APP_DIR/SETUP_INFO.md"
}

# Main installation function
main() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Member Management System Installer   ${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo
    
    get_domain
    
    log "Starting installation..."
    install_dependencies
    remove_existing_installation
    setup_user_and_directories
    install_pocketbase
    create_systemd_service
    configure_nginx
    configure_firewall
    setup_fail2ban
    create_backup_script
    setup_log_rotation
    create_config_file
    initialize_pocketbase
    
    # Attempt SSL setup (may fail if DNS not configured)
    setup_ssl || warn "SSL setup failed - you may need to configure DNS first"
    
    echo
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}     Installation Complete!            ${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo
    echo -e "${BLUE}Next Steps:${NC}"
    echo "1. Configure DNS to point both domains to this server's IP"
    echo "2. Run SSL setup: sudo certbot --nginx -d $MAIN_DOMAIN -d $ADMIN_DOMAIN"
    echo "3. Access the main system: https://$MAIN_DOMAIN/"
    echo "4. Access the admin panel: https://$ADMIN_DOMAIN/_/"
    echo "   (or temporarily: http://$(curl -s ipecho.net/plain):8090/_/)"
    echo "3. Create your first admin user"
    echo "4. Import the database schema"
    echo "5. Configure your associations"
    echo
    echo -e "${BLUE}System Information:${NC}"
    echo "- Service status: $(systemctl is-active pocketbase)"
    echo "- Server IP: $(curl -s ipecho.net/plain || echo 'Unable to detect')"
    echo "- View logs: sudo journalctl -u pocketbase -f"
    echo "- Configuration: $APP_DIR/SETUP_INFO.md"
    echo
    echo -e "${YELLOW}DNS Configuration Required:${NC}"
    echo "Point these domains to your server IP:"
    echo "- $MAIN_DOMAIN"
    echo "- $ADMIN_DOMAIN"
    echo
    echo -e "${YELLOW}Important:${NC} Save the admin credentials in a secure location!"
    echo
}

# Run main function
main "$@"
