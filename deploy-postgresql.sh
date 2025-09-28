#!/bin/bash

# Member Management System - PostgreSQL Deployment Script
# Compatible with Debian 11+ and Ubuntu 20.04+
# Run as root or with sudo privileges

set -e  # Exit on any error

# Configuration
POSTGRES_VERSION="15"
APP_USER="memberapp"
APP_DIR="/opt/member-management"
DATA_DIR="/var/lib/member-management"
NGINX_SITE="member-management"
DB_NAME="member_management"
DB_USER="memberapp_user"
DB_PASSWORD=""
MAIN_DOMAIN=""
ADMIN_DOMAIN=""
RESEND_API_KEY=""

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

# Generate secure password
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

# Remove existing PocketBase installation
remove_existing_installation() {
    log "Checking for existing PocketBase installation..."
    
    # Run complete PocketBase removal
    if [[ -f "scripts/remove-pocketbase.sh" ]]; then
        log "Running complete PocketBase removal..."
        bash scripts/remove-pocketbase.sh
    else
        warn "PocketBase removal script not found, performing basic cleanup..."
        
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
        
        # Remove PocketBase binary if exists
        if [[ -f "$APP_DIR/pocketbase" ]]; then
            rm -f "$APP_DIR/pocketbase"
        fi
        
        # Remove PocketBase user
        if id "pocketbase" &>/dev/null; then
            userdel -r pocketbase 2>/dev/null || true
        fi
    fi
}

# Get configuration from user
get_configuration() {
    echo -e "${BLUE}=== Member Management System Configuration ===${NC}"
    
    # Database password
    if [[ -z "$DB_PASSWORD" ]]; then
        DB_PASSWORD=$(generate_password)
        log "Generated database password: $DB_PASSWORD"
    fi
    
    # Domains
    MAIN_DOMAIN="member.ringing.org.uk"
    ADMIN_DOMAIN="p.ringing.org.uk"
    
    echo -e "${BLUE}Default domains:${NC}"
    echo "Main system: $MAIN_DOMAIN"
    echo "Admin panel: $ADMIN_DOMAIN"
    
    read -p "Press Enter to continue or type 'custom' to use different domains: " choice
    
    if [[ "$choice" == "custom" ]]; then
        while [[ -z "$MAIN_DOMAIN" ]]; do
            read -p "Enter main domain (e.g., member.yourorg.com): " MAIN_DOMAIN
        done
        
        while [[ -z "$ADMIN_DOMAIN" ]]; do
            read -p "Enter admin domain (e.g., p.yourorg.com): " ADMIN_DOMAIN
        done
    fi
    
    # Resend API Key
    echo -e "${BLUE}Email Configuration:${NC}"
    read -p "Enter Resend API key (optional, press Enter to skip): " RESEND_API_KEY
    
    echo -e "${BLUE}Configuration Summary:${NC}"
    echo "Database: $DB_NAME"
    echo "Database User: $DB_USER"
    echo "Main Domain: $MAIN_DOMAIN"
    echo "Admin Domain: $ADMIN_DOMAIN"
    echo "Resend API: $([ -n "$RESEND_API_KEY" ] && echo "Configured" || echo "Not configured")"
    
    read -p "Continue with this configuration? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        error "Installation cancelled"
    fi
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
        logrotate \
        postgresql-$POSTGRES_VERSION \
        postgresql-contrib-$POSTGRES_VERSION \
        postgresql-client-$POSTGRES_VERSION \
        git \
        build-essential \
        python3-pip \
        python3-venv
    
    # Install Node.js and npm separately to avoid conflicts
    install_nodejs
}

# Install Node.js and npm with conflict resolution
install_nodejs() {
    log "Installing Node.js and npm..."
    
    # Remove any existing nodejs/npm packages that might conflict
    apt-get remove -y nodejs npm node-* 2>/dev/null || true
    
    # Clean up any leftover files
    rm -rf /usr/lib/node_modules 2>/dev/null || true
    rm -f /usr/bin/node /usr/bin/npm /usr/bin/npx 2>/dev/null || true
    
    # Add NodeSource repository if not already added
    if ! grep -q "nodesource" /etc/apt/sources.list.d/* 2>/dev/null; then
        log "Adding NodeSource repository..."
        curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    fi
    
    # Update package list
    apt-get update
    
    # Install nodejs (which includes npm from NodeSource)
    apt-get install -y nodejs
    
    # Verify installation
    if ! command -v node >/dev/null 2>&1; then
        error "Node.js installation failed"
    fi
    
    if ! command -v npm >/dev/null 2>&1; then
        error "npm installation failed"
    fi
    
    log "Node.js version: $(node --version)"
    log "npm version: $(npm --version)"
}

# Setup PostgreSQL
setup_postgresql() {
    log "Configuring PostgreSQL..."
    
    # Start and enable PostgreSQL
    systemctl start postgresql
    systemctl enable postgresql
    
    # Create database and user
    sudo -u postgres psql << EOF
CREATE DATABASE $DB_NAME;
CREATE USER $DB_USER WITH ENCRYPTED PASSWORD '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
ALTER USER $DB_USER CREATEDB;
\q
EOF

    # Configure PostgreSQL for better performance
    PG_CONFIG="/etc/postgresql/$POSTGRES_VERSION/main/postgresql.conf"
    PG_HBA="/etc/postgresql/$POSTGRES_VERSION/main/pg_hba.conf"
    
    # Backup original configs
    cp "$PG_CONFIG" "$PG_CONFIG.backup"
    cp "$PG_HBA" "$PG_HBA.backup"
    
    # Update PostgreSQL configuration
    cat >> "$PG_CONFIG" << EOF

# Member Management System Optimizations
shared_buffers = 256MB
effective_cache_size = 1GB
maintenance_work_mem = 64MB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 1.1
effective_io_concurrency = 200
work_mem = 4MB
min_wal_size = 1GB
max_wal_size = 4GB
max_worker_processes = 8
max_parallel_workers_per_gather = 2
max_parallel_workers = 8
max_parallel_maintenance_workers = 2
EOF

    # Update pg_hba.conf for local connections
    sed -i "s/#listen_addresses = 'localhost'/listen_addresses = 'localhost'/" "$PG_CONFIG"
    
    # Restart PostgreSQL
    systemctl restart postgresql
    
    # Test connection
    if sudo -u postgres psql -d "$DB_NAME" -c "SELECT version();" > /dev/null 2>&1; then
        log "PostgreSQL setup completed successfully"
    else
        error "PostgreSQL setup failed"
    fi
}

# Run database migrations
run_database_migrations() {
    log "Running database migrations..."
    
    # Create migrations directory if it doesn't exist
    mkdir -p "$APP_DIR/database/postgresql"
    
    # Copy migration files
    if [[ -d "database/postgresql" ]]; then
        cp -r database/postgresql/* "$APP_DIR/database/postgresql/"
    fi
    
    # Run migrations in order
    for migration_file in "$APP_DIR/database/postgresql/schema"/*.sql; do
        if [[ -f "$migration_file" ]]; then
            log "Running migration: $(basename "$migration_file")"
            sudo -u postgres psql -d "$DB_NAME" -f "$migration_file"
        fi
    done
    
    log "Database migrations completed"
}

# Create application user and directories
setup_application() {
    log "Setting up application environment..."
    
    # Create application user
    if ! id "$APP_USER" &>/dev/null; then
        useradd --system --shell /bin/bash --home-dir "$DATA_DIR" --create-home "$APP_USER"
    fi
    
    # Create directories
    mkdir -p "$APP_DIR"
    mkdir -p "$DATA_DIR"
    mkdir -p "$DATA_DIR/logs"
    mkdir -p "$DATA_DIR/uploads"
    mkdir -p "$DATA_DIR/backups"
    mkdir -p "/var/log/member-management"
    
    # Set permissions
    chown -R "$APP_USER:$APP_USER" "$DATA_DIR"
    chown -R "$APP_USER:$APP_USER" "/var/log/member-management"
    chmod 755 "$APP_DIR"
    chmod 750 "$DATA_DIR"
}

# Install Node.js application
install_nodejs_app() {
    log "Installing Node.js application..."
    
    # Create package.json
    cat > "$APP_DIR/package.json" << EOF
{
  "name": "member-management-system",
  "version": "1.0.0",
  "description": "Member Management System with PostgreSQL and Resend",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js",
    "migrate": "node scripts/migrate.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "pg": "^8.11.3",
    "bcryptjs": "^2.4.3",
    "jsonwebtoken": "^9.0.2",
    "cors": "^2.8.5",
    "helmet": "^7.1.0",
    "express-rate-limit": "^7.1.5",
    "multer": "^1.4.5-lts.1",
    "resend": "^2.1.0",
    "dotenv": "^16.3.1",
    "joi": "^17.11.0",
    "winston": "^3.11.0",
    "compression": "^1.7.4"
  },
  "devDependencies": {
    "nodemon": "^3.0.2"
  },
  "engines": {
    "node": ">=18.0.0"
  }
}
EOF

    # Install dependencies
    cd "$APP_DIR"
    npm install
    
    # Set ownership
    chown -R "$APP_USER:$APP_USER" "$APP_DIR"
}

# Create application configuration
create_app_config() {
    log "Creating application configuration..."
    
    cat > "$APP_DIR/.env" << EOF
# Database Configuration
DB_HOST=localhost
DB_PORT=5432
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD

# Application Configuration
NODE_ENV=production
PORT=3000
JWT_SECRET=$(generate_password)
SESSION_SECRET=$(generate_password)

# Domain Configuration
MAIN_DOMAIN=$MAIN_DOMAIN
ADMIN_DOMAIN=$ADMIN_DOMAIN

# Email Configuration (Resend)
RESEND_API_KEY=$RESEND_API_KEY
FROM_EMAIL=noreply@$MAIN_DOMAIN

# File Upload Configuration
UPLOAD_DIR=$DATA_DIR/uploads
MAX_FILE_SIZE=10485760

# Logging
LOG_LEVEL=info
LOG_DIR=/var/log/member-management

# Security
BCRYPT_ROUNDS=12
JWT_EXPIRES_IN=24h
RATE_LIMIT_WINDOW=15
RATE_LIMIT_MAX=100
EOF

    chmod 600 "$APP_DIR/.env"
    chown "$APP_USER:$APP_USER" "$APP_DIR/.env"
}

# Create systemd service
create_systemd_service() {
    log "Creating systemd service..."
    
    cat > "/etc/systemd/system/member-management.service" << EOF
[Unit]
Description=Member Management System
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=simple
User=$APP_USER
Group=$APP_USER
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=5
Environment=NODE_ENV=production
EnvironmentFile=$APP_DIR/.env

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$DATA_DIR /var/log/member-management

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=member-management

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable member-management
}

# Configure Nginx
configure_nginx() {
    log "Configuring Nginx..."
    
    # Remove default site
    rm -f /etc/nginx/sites-enabled/default
    
    # Add rate limiting to main nginx.conf
    if ! grep -q "limit_req_zone" /etc/nginx/nginx.conf; then
        sed -i '/http {/a\\tlimit_req_zone $binary_remote_addr zone=api:10m rate=10r/m;\n\tlimit_req_zone $binary_remote_addr zone=login:10m rate=5r/m;' /etc/nginx/nginx.conf
    fi
    
    # Create main site configuration
    cat > "/etc/nginx/sites-available/member-management" << EOF
# Main application server
server {
    listen 80;
    server_name $MAIN_DOMAIN;
    
    rm -f /etc/nginx/sites-available/member-management
    rm -f /etc/nginx/sites-enabled/member-management
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    
    # File upload size limit
    client_max_body_size 100M;
    
    # Health check endpoint
    location /health {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # API endpoints with rate limiting
    location /api/ {
        limit_req zone=api burst=20 nodelay;
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # Main application
    location / {
        proxy_pass http://127.0.0.1:3000;
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
}
    # Create single site configuration for both domains
    cat > "/etc/nginx/sites-available/member-management" << EOF
# Main application server for both domains
server {
    listen 80;
    server_name $MAIN_DOMAIN $ADMIN_DOMAIN;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    
    # Admin interface
    location / {
        limit_req zone=login burst=5 nodelay;
    # Health check endpoint
    location /health {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # Admin panel access (for p.ringing.org.uk)
    location /admin {
        proxy_pass http://127.0.0.1:3000;
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
    
    # API endpoints
    location /api/ {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # Static files
    location /static/ {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # Main application
        
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

    # Enable site
    ln -sf "/etc/nginx/sites-available/member-management" "/etc/nginx/sites-enabled/"
    
        warn "Admin domain $ADMIN_DOMAIN: $ADMIN_DOMAIN_IP (should be $PUBLIC_IP)"
        warn "SSL certificate setup skipped. Please configure DNS and run:"
        warn "certbot --nginx -d $MAIN_DOMAIN -d $ADMIN_DOMAIN"
    # Enable the site
    systemctl enable fail2ban
EOF

    # Create custom filter for member management
    # Create custom filter for member management
    cat > "/etc/fail2ban/filter.d/member-management.conf" << EOF
[Definition]
failregex = ^.*Authentication failed for.*<HOST>.*$
            ^.*Invalid login attempt from.*<HOST>.*$
            ^.*Suspicious activity from.*<HOST>.*$
ignoreregex =
EOF

    # Add member-management jail to jail.local
    cat >> "/etc/fail2ban/jail.local" << EOF

[nginx-noscript]
enabled = true
filter = nginx-noscript
logpath = /var/log/nginx/access.log
maxretry = 6

[member-management]
enabled = true
filter = member-management
logpath = /var/log/member-management/app.log
maxretry = 5
bantime = 1800
EOF

    systemctl restart fail2ban
}

# Create backup script
create_backup_script() {
    log "Creating backup script..."
    
    cat > "/usr/local/bin/backup-member-management" << 'EOF'
#!/bin/bash

BACKUP_DIR="/var/lib/member-management/backups"
DATE=$(date +%Y%m%d_%H%M%S)
DB_BACKUP_FILE="$BACKUP_DIR/database_backup_$DATE.sql"
FILES_BACKUP_FILE="$BACKUP_DIR/files_backup_$DATE.tar.gz"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Database backup
sudo -u postgres pg_dump member_management > "$DB_BACKUP_FILE"

# Files backup
tar -czf "$FILES_BACKUP_FILE" -C /var/lib/member-management uploads

# Compress database backup
gzip "$DB_BACKUP_FILE"

# Keep only last 7 backups
cd "$BACKUP_DIR"
ls -t database_backup_*.sql.gz | tail -n +8 | xargs rm -f
ls -t files_backup_*.tar.gz | tail -n +8 | xargs rm -f

echo "Backup created: database_backup_$DATE.sql.gz and files_backup_$DATE.tar.gz"
EOF

    chmod +x "/usr/local/bin/backup-member-management"
    
    # Setup daily backup cron job
    cat > "/etc/cron.daily/member-management-backup" << 'EOF'
#!/bin/bash
/usr/local/bin/backup-member-management >> /var/log/member-management/backup.log 2>&1
EOF

    chmod +x "/etc/cron.daily/member-management-backup"
}

# Setup log rotation
setup_log_rotation() {
    log "Setting up log rotation..."
    
    cat > "/etc/logrotate.d/member-management" << EOF
/var/log/member-management/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 644 $APP_USER $APP_USER
    postrotate
        systemctl reload member-management
    endscript
}
EOF
}

# Health check function
health_check() {
    log "Performing health checks..."
    
    # Check PostgreSQL
    if sudo -u postgres psql -d "$DB_NAME" -c "SELECT 1;" > /dev/null 2>&1; then
        log "✓ PostgreSQL is running and accessible"
    else
        error "✗ PostgreSQL health check failed"
    fi
    
    # Ensure application files exist
    if [[ ! -f "$APP_DIR/server.js" ]]; then
        warn "Application files missing, copying from project..."
        if [[ -d "backend" ]]; then
            cp -r backend/* "$APP_DIR/"
            chown -R "$APP_USER:$APP_USER" "$APP_DIR"
        else
            warn "Backend files not found in current directory"
        fi
    fi
    
    # Install dependencies if needed
    if [[ ! -d "$APP_DIR/node_modules" ]]; then
        log "Installing Node.js dependencies..."
        cd "$APP_DIR"
        npm install
        chown -R "$APP_USER:$APP_USER" "$APP_DIR"
    fi
    
    # Check if application starts
    systemctl start member-management
    sleep 10
    
    if systemctl is-active --quiet member-management; then
        log "✓ Member Management service is running"
    else
        warn "⚠ Member Management service failed to start"
        log "Checking service logs..."
        journalctl -u member-management --no-pager -l -n 20
        
        # Try to start manually for debugging
        log "Attempting manual start for debugging..."
        cd "$APP_DIR"
        timeout 10s sudo -u "$APP_USER" node server.js || log "Manual start failed or timed out"
    fi
    
    # Check if application responds
    sleep 5
    if curl -f -s --connect-timeout 5 http://127.0.0.1:3000/health > /dev/null 2>&1; then
        log "✓ Application is responding to HTTP requests"
    else
        warn "⚠ Application health endpoint not responding (this may be normal during initial setup)"
        log "Checking if port 3000 is listening..."
        netstat -tlnp | grep :3000 || log "Port 3000 is not listening"
    fi
    
    # Check Nginx
    if systemctl is-active --quiet nginx; then
        log "✓ Nginx is running"
    else
        warn "⚠ Nginx is not running"
        systemctl start nginx
    fi
}

# Create setup documentation
create_documentation() {
    log "Creating setup documentation..."
    
    cat > "$APP_DIR/SETUP_INFO.md" << EOF
# Member Management System - PostgreSQL Setup Information

## Installation Details
- Installation Date: $(date)
- Main Domain: $MAIN_DOMAIN
- Admin Domain: $ADMIN_DOMAIN
- Database: PostgreSQL $POSTGRES_VERSION
- Application Directory: $APP_DIR
- Data Directory: $DATA_DIR

## Database Information
- Database Name: $DB_NAME
- Database User: $DB_USER
- Database Password: $DB_PASSWORD (keep secure!)

## Important URLs
- Main System: https://$MAIN_DOMAIN/
- Admin Panel: https://$ADMIN_DOMAIN/
- API Base URL: https://$MAIN_DOMAIN/api/

## Service Management
\`\`\`bash
# Application service
sudo systemctl start member-management
sudo systemctl stop member-management
sudo systemctl restart member-management
sudo systemctl status member-management

# View logs
sudo journalctl -u member-management -f
sudo tail -f /var/log/member-management/app.log

# PostgreSQL service
sudo systemctl start postgresql
sudo systemctl stop postgresql
sudo systemctl restart postgresql
\`\`\`

## Database Management
\`\`\`bash
# Connect to database
sudo -u postgres psql -d $DB_NAME

# Create database backup
sudo -u postgres pg_dump $DB_NAME > backup.sql

# Restore database
sudo -u postgres psql -d $DB_NAME < backup.sql

# Run migrations
cd $APP_DIR && npm run migrate
\`\`\`

## Backup and Restore
\`\`\`bash
# Manual backup
sudo /usr/local/bin/backup-member-management

# List backups
ls -la $DATA_DIR/backups/

# Restore database from backup
sudo -u postgres psql -d $DB_NAME < $DATA_DIR/backups/database_backup_YYYYMMDD_HHMMSS.sql

# Restore files from backup
cd $DATA_DIR && tar -xzf backups/files_backup_YYYYMMDD_HHMMSS.tar.gz
\`\`\`

## Configuration Files
- Application config: $APP_DIR/.env
- Nginx config: /etc/nginx/sites-available/member-management
- PostgreSQL config: /etc/postgresql/$POSTGRES_VERSION/main/postgresql.conf
- Service config: /etc/systemd/system/member-management.service

## Email Configuration (Resend)
$([ -n "$RESEND_API_KEY" ] && echo "Resend API Key is configured in $APP_DIR/.env" || echo "Resend API Key not configured - email features will be disabled")

## Security Notes
- Database password is stored in $APP_DIR/.env (mode 600)
- Application runs as user: $APP_USER
- Firewall is configured to allow only necessary ports
- Fail2ban is configured for intrusion prevention
- SSL certificates are managed by Let's Encrypt

## Next Steps
1. Configure DNS to point domains to this server
2. Run SSL setup if not completed: sudo certbot --nginx -d $MAIN_DOMAIN -d $ADMIN_DOMAIN
3. Access the application and complete initial setup
4. Create your first admin user
5. Configure associations and settings

## Troubleshooting
- Check service logs: sudo journalctl -u member-management -f
- Check application logs: sudo tail -f /var/log/member-management/app.log
- Check Nginx logs: sudo tail -f /var/log/nginx/error.log
- Check PostgreSQL logs: sudo tail -f /var/log/postgresql/postgresql-$POSTGRES_VERSION-main.log
EOF

    chown "$APP_USER:$APP_USER" "$APP_DIR/SETUP_INFO.md"
}

# Main installation function
main() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Member Management System Installer   ${NC}"
    echo -e "${BLUE}     PostgreSQL + Resend Edition       ${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo
    
    get_configuration
    
    log "Starting installation..."
    install_dependencies
    setup_postgresql
    setup_application
    run_database_migrations
    install_nodejs_app
    create_app_config
    create_systemd_service
    configure_nginx
    configure_firewall
    setup_fail2ban
    create_backup_script
    setup_log_rotation
    create_documentation
    health_check
    
    # Attempt SSL setup (may fail if DNS not configured)
    setup_ssl || warn "SSL setup failed - you may need to configure DNS first"
    
    echo
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}     Installation Complete!            ${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo
    echo -e "${BLUE}System Information:${NC}"
    echo "- Main Domain: $MAIN_DOMAIN"
    echo "- Admin Domain: $ADMIN_DOMAIN"
    echo "- Database: PostgreSQL $POSTGRES_VERSION"
    echo "- Application Status: $(systemctl is-active member-management)"
    echo "- Server IP: $(curl -s ipecho.net/plain || echo 'Unable to detect')"
    echo
    echo -e "${BLUE}Important Files:${NC}"
    echo "- Configuration: $APP_DIR/.env"
    echo "- Setup Info: $APP_DIR/SETUP_INFO.md"
    echo "- Database Password: $DB_PASSWORD"
    echo
    echo -e "${BLUE}Next Steps:${NC}"
    echo "1. Configure DNS to point both domains to this server's IP"
    echo "2. Run SSL setup: sudo certbot --nginx -d $MAIN_DOMAIN -d $ADMIN_DOMAIN"
    echo "3. Access the main system: https://$MAIN_DOMAIN/"
    echo "4. Access the admin panel: https://$ADMIN_DOMAIN/"
    echo "5. Complete the initial setup and create your first admin user"
    echo
    echo -e "${YELLOW}Security Reminder:${NC}"
    echo "- Database password: $DB_PASSWORD"
    echo "- Save this password in a secure location!"
    echo "- Configuration file: $APP_DIR/.env (mode 600)"
    echo
    echo -e "${BLUE}Support:${NC}"
    echo "- View logs: sudo journalctl -u member-management -f"
    echo "- Documentation: $APP_DIR/SETUP_INFO.md"
    echo
}

# Run main function
main "$@"