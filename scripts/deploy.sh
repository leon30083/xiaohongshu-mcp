#!/bin/bash

# Xiaohongshu MCP One-Click Deployment Script
# This script automates the complete deployment process

set -e  # Exit on any error

# Configuration
INSTALL_DIR="/opt/xiaohongshu-mcp"
SERVICE_USER="xiaohongshu"
DOMAIN=""
EMAIL=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
        exit 1
    fi
}

# Detect OS
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    else
        error "Cannot detect OS"
        exit 1
    fi
    
    log "Detected OS: $OS $VER"
}

# Install Docker
install_docker() {
    log "Installing Docker..."
    
    if command -v docker &> /dev/null; then
        info "Docker is already installed"
        return 0
    fi
    
    # Install Docker using official script
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    
    # Start and enable Docker
    systemctl start docker
    systemctl enable docker
    
    # Install Docker Compose
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    log "Docker installation completed"
}

# Create service user
create_user() {
    log "Creating service user..."
    
    if id "$SERVICE_USER" &>/dev/null; then
        info "User $SERVICE_USER already exists"
    else
        useradd -r -s /bin/false -d "$INSTALL_DIR" "$SERVICE_USER"
        usermod -aG docker "$SERVICE_USER"
        log "User $SERVICE_USER created"
    fi
}

# Setup directories
setup_directories() {
    log "Setting up directories..."
    
    mkdir -p "$INSTALL_DIR"/{data,images,logs,scripts,backup}
    chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"
    chmod 755 "$INSTALL_DIR"
    
    log "Directories created"
}

# Create Docker Compose file
create_compose_file() {
    log "Creating Docker Compose configuration..."
    
    cat > "$INSTALL_DIR/docker-compose.yml" << EOF
services:
  xiaohongshu-mcp:
    image: xpzouying/xiaohongshu-mcp:latest
    container_name: xiaohongshu-mcp
    restart: unless-stopped
    user: "$(id -u $SERVICE_USER):$(id -g $SERVICE_USER)"
    tty: true
    volumes:
      - ./data:/app/data
      - ./images:/app/images
      - ./logs:/app/logs
    environment:
      - ROD_BROWSER_BIN=/usr/bin/google-chrome
      - COOKIES_PATH=/app/data/cookies.json
      - LOG_LEVEL=info
    ports:
      - "127.0.0.1:18060:18060"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:18060/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    logging:
      driver: "json-file"
      options:
        max-size: "100m"
        max-file: "5"
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 4G
        reservations:
          cpus: '0.5'
          memory: 1G
EOF
    
    chown "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR/docker-compose.yml"
    log "Docker Compose file created"
}

# Install Nginx
install_nginx() {
    log "Installing Nginx..."
    
    if command -v nginx &> /dev/null; then
        info "Nginx is already installed"
        return 0
    fi
    
    case "$OS" in
        *"Ubuntu"*|*"Debian"*)
            apt update
            apt install -y nginx
            ;;
        *"CentOS"*|*"Red Hat"*)
            yum install -y nginx
            ;;
        *)
            warning "Unsupported OS for automatic Nginx installation"
            return 1
            ;;
    esac
    
    systemctl start nginx
    systemctl enable nginx
    
    log "Nginx installation completed"
}

# Configure Nginx
configure_nginx() {
    if [[ -z "$DOMAIN" ]]; then
        warning "No domain specified, skipping Nginx configuration"
        return 0
    fi
    
    log "Configuring Nginx for domain: $DOMAIN"
    
    cat > "/etc/nginx/sites-available/xiaohongshu-mcp" << EOF
server {
    listen 80;
    server_name $DOMAIN;
    
    location / {
        proxy_pass http://127.0.0.1:18060;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
}
EOF
    
    # Enable site
    ln -sf /etc/nginx/sites-available/xiaohongshu-mcp /etc/nginx/sites-enabled/
    
    # Test configuration
    nginx -t
    systemctl reload nginx
    
    log "Nginx configuration completed"
}

# Install SSL certificate
install_ssl() {
    if [[ -z "$DOMAIN" ]] || [[ -z "$EMAIL" ]]; then
        warning "Domain or email not specified, skipping SSL installation"
        return 0
    fi
    
    log "Installing SSL certificate for $DOMAIN"
    
    # Install certbot
    case "$OS" in
        *"Ubuntu"*|*"Debian"*)
            apt install -y certbot python3-certbot-nginx
            ;;
        *"CentOS"*|*"Red Hat"*)
            yum install -y certbot python3-certbot-nginx
            ;;
        *)
            warning "Unsupported OS for automatic certbot installation"
            return 1
            ;;
    esac
    
    # Get certificate
    certbot --nginx -d "$DOMAIN" --email "$EMAIL" --agree-tos --non-interactive
    
    log "SSL certificate installed"
}

# Setup firewall
setup_firewall() {
    log "Configuring firewall..."
    
    if command -v ufw &> /dev/null; then
        ufw --force enable
        ufw allow ssh
        ufw allow 'Nginx Full'
        ufw --force reload
        log "UFW firewall configured"
    elif command -v firewall-cmd &> /dev/null; then
        systemctl start firewalld
        systemctl enable firewalld
        firewall-cmd --permanent --add-service=ssh
        firewall-cmd --permanent --add-service=http
        firewall-cmd --permanent --add-service=https
        firewall-cmd --reload
        log "Firewalld configured"
    else
        warning "No supported firewall found"
    fi
}

# Create systemd service
create_systemd_service() {
    log "Creating systemd service..."
    
    cat > "/etc/systemd/system/xiaohongshu-mcp.service" << EOF
[Unit]
Description=Xiaohongshu MCP Service
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
User=$SERVICE_USER
Group=$SERVICE_USER

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable xiaohongshu-mcp.service
    
    log "Systemd service created"
}

# Deploy application
deploy_app() {
    log "Deploying application..."
    
    cd "$INSTALL_DIR"
    
    # Pull latest image
    docker pull xpzouying/xiaohongshu-mcp:latest
    
    # Start services
    sudo -u "$SERVICE_USER" docker-compose up -d
    
    # Wait for service to be ready
    sleep 30
    
    # Check if service is running
    if curl -f -s http://localhost:18060/health > /dev/null; then
        log "Application deployed successfully"
    else
        error "Application deployment failed"
        exit 1
    fi
}

# Setup monitoring
setup_monitoring() {
    log "Setting up monitoring..."
    
    # Copy monitor script
    cp "$(dirname "$0")/monitor.sh" "$INSTALL_DIR/scripts/"
    chmod +x "$INSTALL_DIR/scripts/monitor.sh"
    chown "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR/scripts/monitor.sh"
    
    # Create cron job for monitoring
    cat > "/etc/cron.d/xiaohongshu-mcp" << EOF
# Xiaohongshu MCP Monitoring
*/5 * * * * $SERVICE_USER $INSTALL_DIR/scripts/monitor.sh check
0 2 * * * $SERVICE_USER $INSTALL_DIR/scripts/monitor.sh backup
EOF
    
    log "Monitoring setup completed"
}

# Print deployment summary
print_summary() {
    echo ""
    echo -e "${GREEN}================================${NC}"
    echo -e "${GREEN}  Deployment Completed!${NC}"
    echo -e "${GREEN}================================${NC}"
    echo ""
    echo -e "${BLUE}Service Information:${NC}"
    echo "  - Install Directory: $INSTALL_DIR"
    echo "  - Service User: $SERVICE_USER"
    echo "  - Local URL: http://localhost:18060"
    
    if [[ -n "$DOMAIN" ]]; then
        echo "  - Public URL: https://$DOMAIN"
    fi
    
    echo ""
    echo -e "${BLUE}Management Commands:${NC}"
    echo "  - Check status: $INSTALL_DIR/scripts/monitor.sh status"
    echo "  - View logs: $INSTALL_DIR/scripts/monitor.sh logs"
    echo "  - Restart service: systemctl restart xiaohongshu-mcp"
    echo "  - Update service: $INSTALL_DIR/scripts/monitor.sh update"
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "  1. Access the service at http://localhost:18060"
    echo "  2. Use MCP Inspector to get login QR code"
    echo "  3. Scan QR code with Xiaohongshu app to login"
    echo ""
}

# Main deployment function
main() {
    log "Starting Xiaohongshu MCP deployment..."
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --domain)
                DOMAIN="$2"
                shift 2
                ;;
            --email)
                EMAIL="$2"
                shift 2
                ;;
            --install-dir)
                INSTALL_DIR="$2"
                shift 2
                ;;
            *)
                error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    check_root
    detect_os
    install_docker
    create_user
    setup_directories
    create_compose_file
    install_nginx
    configure_nginx
    install_ssl
    setup_firewall
    create_systemd_service
    deploy_app
    setup_monitoring
    print_summary
    
    log "Deployment completed successfully!"
}

# Show usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --domain DOMAIN      Domain name for the service"
    echo "  --email EMAIL        Email for SSL certificate"
    echo "  --install-dir DIR    Installation directory (default: /opt/xiaohongshu-mcp)"
    echo ""
    echo "Example:"
    echo "  $0 --domain mcp.example.com --email admin@example.com"
}

# Handle help
if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    usage
    exit 0
fi

# Run main function
main "$@"