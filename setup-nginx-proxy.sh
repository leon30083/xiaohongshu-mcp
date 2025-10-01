#!/bin/bash

# Xiaohongshu MCP Nginx Proxy Setup Script
# Run this script on your Linux ARM64 server

set -e

echo "🚀 Setting up Nginx proxy for Xiaohongshu MCP..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get Windows PC IP address
echo -e "${YELLOW}Please enter your Windows PC IP address (where MCP is running):${NC}"
read -p "Windows PC IP: " WINDOWS_PC_IP

if [[ ! $WINDOWS_PC_IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    echo -e "${RED}Invalid IP address format!${NC}"
    exit 1
fi

echo -e "${GREEN}Using Windows PC IP: $WINDOWS_PC_IP${NC}"

# Update system
echo -e "${YELLOW}Updating system packages...${NC}"
sudo apt update

# Install Nginx
echo -e "${YELLOW}Installing Nginx...${NC}"
sudo apt install -y nginx

# Create Nginx configuration
echo -e "${YELLOW}Creating Nginx configuration...${NC}"
sudo tee /etc/nginx/sites-available/xiaohongshu-mcp > /dev/null <<EOF
server {
    listen 8080;
    server_name _;
    
    # Access log
    access_log /var/log/nginx/xiaohongshu-mcp.access.log;
    error_log /var/log/nginx/xiaohongshu-mcp.error.log;
    
    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\\n";
        add_header Content-Type text/plain;
    }
    
    # MCP proxy
    location /mcp {
        proxy_pass http://$WINDOWS_PC_IP:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Timeout settings
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Buffer settings
        proxy_buffering off;
        proxy_request_buffering off;
    }
    
    # Root path redirect
    location / {
        proxy_pass http://$WINDOWS_PC_IP:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Timeout settings
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF

# Enable the site
echo -e "${YELLOW}Enabling Nginx site...${NC}"
sudo ln -sf /etc/nginx/sites-available/xiaohongshu-mcp /etc/nginx/sites-enabled/

# Remove default site if exists
sudo rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
echo -e "${YELLOW}Testing Nginx configuration...${NC}"
if sudo nginx -t; then
    echo -e "${GREEN}Nginx configuration is valid!${NC}"
else
    echo -e "${RED}Nginx configuration has errors!${NC}"
    exit 1
fi

# Configure firewall
echo -e "${YELLOW}Configuring firewall...${NC}"
if command -v ufw &> /dev/null; then
    sudo ufw allow 8080/tcp
    echo -e "${GREEN}UFW firewall rule added for port 8080${NC}"
elif command -v firewall-cmd &> /dev/null; then
    sudo firewall-cmd --permanent --add-port=8080/tcp
    sudo firewall-cmd --reload
    echo -e "${GREEN}Firewalld rule added for port 8080${NC}"
fi

# Start and enable Nginx
echo -e "${YELLOW}Starting Nginx...${NC}"
sudo systemctl restart nginx
sudo systemctl enable nginx

# Get server IP
SERVER_IP=$(hostname -I | awk '{print $1}')

# Test connectivity to Windows PC
echo -e "${YELLOW}Testing connectivity to Windows PC...${NC}"
if nc -z $WINDOWS_PC_IP 8080; then
    echo -e "${GREEN}✅ Can connect to Windows PC on port 8080${NC}"
else
    echo -e "${RED}❌ Cannot connect to Windows PC on port 8080${NC}"
    echo -e "${YELLOW}Please ensure:${NC}"
    echo "1. MCP proxy server is running on Windows PC"
    echo "2. Windows firewall allows port 8080"
    echo "3. Network connectivity between devices"
fi

# Test local proxy
echo -e "${YELLOW}Testing local proxy...${NC}"
if curl -s http://localhost:8080/health > /dev/null; then
    echo -e "${GREEN}✅ Local proxy health check passed${NC}"
else
    echo -e "${RED}❌ Local proxy health check failed${NC}"
fi

echo -e "${GREEN}🎉 Nginx proxy setup completed!${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Configure port forwarding on your main router:"
echo "   External Port: 18080 -> Internal IP: $SERVER_IP -> Internal Port: 8080"
echo ""
echo "2. Test internal access:"
echo "   curl http://$SERVER_IP:8080/health"
echo ""
echo "3. Test external access (after router config):"
echo "   curl http://YOUR_PUBLIC_IP:18080/health"
echo ""
echo "4. Update your Dify configuration to use:"
echo "   http://YOUR_PUBLIC_IP:18080/mcp"
echo ""
echo -e "${YELLOW}Useful commands:${NC}"
echo "- Check Nginx status: sudo systemctl status nginx"
echo "- View access logs: sudo tail -f /var/log/nginx/xiaohongshu-mcp.access.log"
echo "- View error logs: sudo tail -f /var/log/nginx/xiaohongshu-mcp.error.log"
echo "- Restart Nginx: sudo systemctl restart nginx"