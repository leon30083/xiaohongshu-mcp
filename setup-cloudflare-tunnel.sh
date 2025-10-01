#!/bin/bash
# Cloudflare Tunnel Setup Script for Xiaohongshu MCP Service
# 小红书MCP服务Cloudflare隧道自动配置脚本

set -e

echo "🚀 小红书MCP服务 - Cloudflare隧道配置脚本"
echo "=============================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检查是否为root用户
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ 此脚本需要root权限运行${NC}"
   echo "请使用: sudo $0"
   exit 1
fi

# 检测系统架构
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        CLOUDFLARED_ARCH="amd64"
        ;;
    aarch64|arm64)
        CLOUDFLARED_ARCH="arm64"
        ;;
    armv7l)
        CLOUDFLARED_ARCH="arm"
        ;;
    *)
        echo -e "${RED}❌ 不支持的系统架构: $ARCH${NC}"
        exit 1
        ;;
esac

echo -e "${BLUE}📋 检测到系统架构: $ARCH${NC}"

# 步骤1: 安装cloudflared
echo -e "\n${YELLOW}📦 步骤1: 安装cloudflared...${NC}"

if command -v cloudflared &> /dev/null; then
    echo -e "${GREEN}✅ cloudflared已安装${NC}"
    cloudflared --version
else
    echo "下载cloudflared..."
    CLOUDFLARED_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${CLOUDFLARED_ARCH}"
    
    wget -O /tmp/cloudflared "$CLOUDFLARED_URL"
    chmod +x /tmp/cloudflared
    mv /tmp/cloudflared /usr/local/bin/cloudflared
    
    echo -e "${GREEN}✅ cloudflared安装完成${NC}"
    cloudflared --version
fi

# 步骤2: 检查Nginx状态
echo -e "\n${YELLOW}📦 步骤2: 检查Nginx状态...${NC}"

if systemctl is-active --quiet nginx; then
    echo -e "${GREEN}✅ Nginx正在运行${NC}"
else
    echo -e "${RED}❌ Nginx未运行，请先启动Nginx服务${NC}"
    echo "运行: sudo systemctl start nginx"
    exit 1
fi

# 检查8080端口
if netstat -tlnp | grep -q ":8080"; then
    echo -e "${GREEN}✅ 端口8080正在监听${NC}"
else
    echo -e "${RED}❌ 端口8080未监听，请检查Nginx配置${NC}"
    exit 1
fi

# 步骤3: 创建配置目录
echo -e "\n${YELLOW}📦 步骤3: 创建配置目录...${NC}"

mkdir -p /etc/cloudflared
mkdir -p /root/.cloudflared

# 步骤4: 用户交互配置
echo -e "\n${YELLOW}📦 步骤4: 配置隧道...${NC}"

echo -e "${BLUE}请按照以下步骤配置Cloudflare隧道:${NC}"
echo
echo "1. 首先需要登录Cloudflare账户"
echo "2. 运行以下命令进行登录:"
echo -e "${GREEN}   cloudflared tunnel login${NC}"
echo
echo "3. 登录成功后，创建隧道:"
echo -e "${GREEN}   cloudflared tunnel create xiaohongshu-mcp${NC}"
echo
echo "4. 获取隧道ID并配置DNS记录"
echo

read -p "是否现在进行登录配置? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}🔐 启动Cloudflare登录...${NC}"
    cloudflared tunnel login
    
    echo -e "\n${BLUE}🔧 创建隧道...${NC}"
    cloudflared tunnel create xiaohongshu-mcp
    
    # 获取隧道ID
    TUNNEL_ID=$(cloudflared tunnel list | grep xiaohongshu-mcp | awk '{print $1}')
    
    if [ -z "$TUNNEL_ID" ]; then
        echo -e "${RED}❌ 无法获取隧道ID，请手动配置${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ 隧道创建成功，ID: $TUNNEL_ID${NC}"
    
    # 创建配置文件
    echo -e "\n${YELLOW}📝 创建配置文件...${NC}"
    
    read -p "请输入您的域名 (例如: mcp.yourdomain.com): " DOMAIN
    
    cat > /etc/cloudflared/config.yml << EOF
tunnel: $TUNNEL_ID
credentials-file: /root/.cloudflared/$TUNNEL_ID.json

ingress:
  - hostname: $DOMAIN
    service: http://localhost:8080
    originRequest:
      httpHostHeader: $DOMAIN
  - service: http_status:404
EOF
    
    echo -e "${GREEN}✅ 配置文件创建完成${NC}"
    
    # 配置DNS
    echo -e "\n${BLUE}🌐 配置DNS记录...${NC}"
    cloudflared tunnel route dns xiaohongshu-mcp $DOMAIN
    
    echo -e "${GREEN}✅ DNS记录配置完成${NC}"
    
else
    echo -e "${YELLOW}⚠️  跳过自动配置，请手动完成以下步骤:${NC}"
    echo "1. cloudflared tunnel login"
    echo "2. cloudflared tunnel create xiaohongshu-mcp"
    echo "3. 配置 /etc/cloudflared/config.yml"
    echo "4. cloudflared tunnel route dns xiaohongshu-mcp your-domain.com"
fi

# 步骤5: 创建系统服务
echo -e "\n${YELLOW}📦 步骤5: 创建系统服务...${NC}"

cat > /etc/systemd/system/cloudflared.service << EOF
[Unit]
Description=Cloudflare Tunnel
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/cloudflared tunnel run xiaohongshu-mcp
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable cloudflared

echo -e "${GREEN}✅ 系统服务创建完成${NC}"

# 步骤6: 创建管理脚本
echo -e "\n${YELLOW}📦 步骤6: 创建管理脚本...${NC}"

cat > /usr/local/bin/xiaohongshu-tunnel << 'EOF'
#!/bin/bash
# 小红书MCP隧道管理脚本

case "$1" in
    start)
        echo "🚀 启动小红书MCP隧道..."
        sudo systemctl start cloudflared
        echo "✅ 隧道已启动"
        ;;
    stop)
        echo "🛑 停止小红书MCP隧道..."
        sudo systemctl stop cloudflared
        echo "✅ 隧道已停止"
        ;;
    restart)
        echo "🔄 重启小红书MCP隧道..."
        sudo systemctl restart cloudflared
        echo "✅ 隧道已重启"
        ;;
    status)
        echo "📊 小红书MCP隧道状态:"
        sudo systemctl status cloudflared --no-pager
        ;;
    logs)
        echo "📋 小红书MCP隧道日志:"
        sudo journalctl -u cloudflared -f
        ;;
    test)
        echo "🔍 测试本地服务..."
        curl -s http://localhost:8080/health > /dev/null && echo "✅ 本地服务正常" || echo "❌ 本地服务异常"
        ;;
    *)
        echo "用法: $0 {start|stop|restart|status|logs|test}"
        echo
        echo "命令说明:"
        echo "  start   - 启动隧道"
        echo "  stop    - 停止隧道"
        echo "  restart - 重启隧道"
        echo "  status  - 查看状态"
        echo "  logs    - 查看日志"
        echo "  test    - 测试本地服务"
        exit 1
        ;;
esac
EOF

chmod +x /usr/local/bin/xiaohongshu-tunnel

echo -e "${GREEN}✅ 管理脚本创建完成${NC}"

# 完成提示
echo -e "\n${GREEN}🎉 Cloudflare隧道配置完成！${NC}"
echo
echo -e "${BLUE}📋 使用说明:${NC}"
echo "• 启动隧道: xiaohongshu-tunnel start"
echo "• 停止隧道: xiaohongshu-tunnel stop"
echo "• 查看状态: xiaohongshu-tunnel status"
echo "• 查看日志: xiaohongshu-tunnel logs"
echo "• 测试服务: xiaohongshu-tunnel test"
echo
echo -e "${YELLOW}⚠️  重要提醒:${NC}"
echo "1. 确保已完成Cloudflare登录和隧道创建"
echo "2. 确保DNS记录已正确配置"
echo "3. 首次使用请运行: xiaohongshu-tunnel start"
echo
echo -e "${BLUE}🌐 访问地址: https://your-domain.com${NC}"
echo -e "${BLUE}🔍 健康检查: https://your-domain.com/health${NC}"
echo -e "${BLUE}🔌 MCP接口: https://your-domain.com/mcp${NC}"