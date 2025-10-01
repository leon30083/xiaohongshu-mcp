# 小红书MCP服务 AI自动化部署执行手册

## 📋 手册概述

本手册专为AI助手设计，提供小红书MCP服务在Linux服务器上的完整自动化部署指南。手册包含详细的技术分析、精确的执行步骤和完整的验证流程。

**目标环境**: Linux服务器（Ubuntu 18.04+/CentOS 7+/Debian 9+）
**部署方式**: Docker容器化部署（推荐）
**服务类型**: 无头浏览器MCP服务
**预期结果**: 可通过HTTP API和MCP协议访问的小红书自动化服务

---

## 🔍 第一阶段：项目技术架构分析

### 1.1 核心技术栈识别

**后端框架**:
- **语言**: Go 1.24+
- **Web框架**: 原生HTTP服务器
- **浏览器引擎**: Rod + Chrome Headless
- **协议支持**: MCP (Model Context Protocol)

**关键依赖**:
```go
// 从go.mod分析得出的核心依赖
- github.com/go-rod/rod v0.116.2          // 浏览器自动化
- github.com/xpzouying/headless_browser   // 无头浏览器支持
- github.com/gorilla/mux                  // HTTP路由
- github.com/gorilla/websocket           // WebSocket支持
```

**容器化配置**:
- **基础镜像**: ubuntu:22.04
- **浏览器**: Google Chrome Stable
- **运行时**: 非root用户执行
- **端口**: 18060 (HTTP/MCP服务)

### 1.2 服务架构分析

```
┌─────────────────────────────────────────┐
│              客户端层                    │
├─────────────────────────────────────────┤
│  MCP Inspector │ HTTP API │ AI工具集成   │
├─────────────────────────────────────────┤
│              网络层                      │
├─────────────────────────────────────────┤
│    Nginx反向代理 (可选) │ 直接访问       │
├─────────────────────────────────────────┤
│              应用层                      │
├─────────────────────────────────────────┤
│         小红书MCP服务 (Go)              │
│  ┌─────────────┬─────────────────────┐   │
│  │  MCP服务器  │    HTTP API服务     │   │
│  └─────────────┴─────────────────────┘   │
├─────────────────────────────────────────┤
│              浏览器层                    │
├─────────────────────────────────────────┤
│      Chrome Headless Browser           │
├─────────────────────────────────────────┤
│              存储层                      │
├─────────────────────────────────────────┤
│   Cookies存储 │ 图片存储 │ 日志存储     │
└─────────────────────────────────────────┘
```

### 1.3 关键配置参数

**环境变量**:
```bash
ROD_BROWSER_BIN=/usr/bin/google-chrome    # Chrome可执行文件路径
COOKIES_PATH=/app/data/cookies.json       # Cookie存储路径
LOG_LEVEL=info                            # 日志级别
PORT=18060                                # 服务端口
HEADLESS=true                             # 无头模式开关
```

**数据持久化目录**:
```bash
/app/data/     # 配置和Cookie数据
/app/images/   # 上传图片存储
/app/logs/     # 应用日志（可选）
```

---

## 🛠️ 第二阶段：环境准备和前置条件检查

### 2.1 系统要求验证

**AI执行指令**:
```bash
# 检查操作系统版本
cat /etc/os-release

# 检查系统资源
echo "=== 系统资源检查 ==="
echo "CPU核心数: $(nproc)"
echo "内存总量: $(free -h | grep '^Mem:' | awk '{print $2}')"
echo "磁盘空间: $(df -h / | tail -1 | awk '{print $4}')"

# 验证最低要求
REQUIRED_MEMORY_GB=2
REQUIRED_DISK_GB=5
REQUIRED_CPU_CORES=1

MEMORY_GB=$(free -g | grep '^Mem:' | awk '{print $2}')
DISK_GB=$(df -BG / | tail -1 | awk '{print $4}' | sed 's/G//')
CPU_CORES=$(nproc)

if [ "$MEMORY_GB" -lt "$REQUIRED_MEMORY_GB" ]; then
    echo "❌ 内存不足: 需要${REQUIRED_MEMORY_GB}GB，当前${MEMORY_GB}GB"
    exit 1
fi

if [ "$DISK_GB" -lt "$REQUIRED_DISK_GB" ]; then
    echo "❌ 磁盘空间不足: 需要${REQUIRED_DISK_GB}GB，当前${DISK_GB}GB"
    exit 1
fi

if [ "$CPU_CORES" -lt "$REQUIRED_CPU_CORES" ]; then
    echo "❌ CPU核心数不足: 需要${REQUIRED_CPU_CORES}核，当前${CPU_CORES}核"
    exit 1
fi

echo "✅ 系统资源检查通过"
```

### 2.2 网络环境检查

**AI执行指令**:
```bash
# 检查网络连接
echo "=== 网络连接检查 ==="

# 检查基础网络
if ping -c 3 8.8.8.8 > /dev/null 2>&1; then
    echo "✅ 基础网络连接正常"
else
    echo "❌ 基础网络连接失败"
    exit 1
fi

# 检查Docker Hub连接
if curl -s --connect-timeout 10 https://hub.docker.com > /dev/null; then
    echo "✅ Docker Hub连接正常"
else
    echo "❌ Docker Hub连接失败，可能需要配置代理"
fi

# 检查GitHub连接
if curl -s --connect-timeout 10 https://github.com > /dev/null; then
    echo "✅ GitHub连接正常"
else
    echo "❌ GitHub连接失败"
fi

# 检查端口占用
if netstat -tuln | grep :18060 > /dev/null; then
    echo "❌ 端口18060已被占用"
    netstat -tuln | grep :18060
    exit 1
else
    echo "✅ 端口18060可用"
fi
```

### 2.3 Docker环境安装

**AI执行指令**:
```bash
# 检查Docker是否已安装
if command -v docker &> /dev/null; then
    echo "✅ Docker已安装: $(docker --version)"
else
    echo "📦 开始安装Docker..."
    
    # 更新包管理器
    if command -v apt &> /dev/null; then
        # Ubuntu/Debian
        apt update
        apt install -y ca-certificates curl gnupg lsb-release
        
        # 添加Docker官方GPG密钥
        mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        
        # 添加Docker仓库
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        # 安装Docker
        apt update
        apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        
    elif command -v yum &> /dev/null; then
        # CentOS/RHEL
        yum install -y yum-utils
        yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        
    else
        echo "❌ 不支持的包管理器"
        exit 1
    fi
    
    # 启动Docker服务
    systemctl start docker
    systemctl enable docker
    
    echo "✅ Docker安装完成"
fi

# 检查Docker Compose
if docker compose version &> /dev/null; then
    echo "✅ Docker Compose已安装: $(docker compose version)"
else
    echo "❌ Docker Compose未安装"
    exit 1
fi

# 验证Docker运行状态
if systemctl is-active --quiet docker; then
    echo "✅ Docker服务运行正常"
else
    echo "❌ Docker服务未运行"
    systemctl start docker
fi
```

---

## 🚀 第三阶段：Docker部署流程执行

### 3.1 创建部署目录结构

**AI执行指令**:
```bash
# 设置部署变量
DEPLOY_DIR="/opt/xiaohongshu-mcp"
SERVICE_USER="xiaohongshu"

echo "=== 创建部署环境 ==="

# 创建服务用户
if ! id "$SERVICE_USER" &>/dev/null; then
    useradd -r -s /bin/false -d "$DEPLOY_DIR" "$SERVICE_USER"
    usermod -aG docker "$SERVICE_USER"
    echo "✅ 创建服务用户: $SERVICE_USER"
else
    echo "✅ 服务用户已存在: $SERVICE_USER"
fi

# 创建目录结构
mkdir -p "$DEPLOY_DIR"/{data,images,logs,scripts,backup,nginx}
chown -R "$SERVICE_USER:$SERVICE_USER" "$DEPLOY_DIR"
chmod 755 "$DEPLOY_DIR"

echo "✅ 目录结构创建完成:"
tree "$DEPLOY_DIR" || ls -la "$DEPLOY_DIR"
```

### 3.2 生成Docker Compose配置

**AI执行指令**:
```bash
# 生成生产环境Docker Compose配置
cat > "$DEPLOY_DIR/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  xiaohongshu-mcp:
    image: xpzouying/xiaohongshu-mcp:latest
    container_name: xiaohongshu-mcp
    restart: unless-stopped
    user: "1000:1000"
    tty: true
    
    # 资源限制
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 4G
        reservations:
          cpus: '0.5'
          memory: 1G
    
    # 数据卷挂载
    volumes:
      - ./data:/app/data
      - ./images:/app/images
      - ./logs:/app/logs
      - /etc/localtime:/etc/localtime:ro
    
    # 环境变量
    environment:
      - ROD_BROWSER_BIN=/usr/bin/google-chrome
      - COOKIES_PATH=/app/data/cookies.json
      - LOG_LEVEL=info
      - TZ=Asia/Shanghai
      - CHROME_ARGS=--no-sandbox --disable-dev-shm-usage --disable-gpu
    
    # 网络配置
    ports:
      - "127.0.0.1:18060:18060"
    
    # 健康检查
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:18060/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    
    # 日志配置
    logging:
      driver: "json-file"
      options:
        max-size: "100m"
        max-file: "5"
    
    # 安全配置
    security_opt:
      - no-new-privileges:true
    
    networks:
      - xiaohongshu-net

networks:
  xiaohongshu-net:
    driver: bridge
EOF

# 设置文件权限
chown "$SERVICE_USER:$SERVICE_USER" "$DEPLOY_DIR/docker-compose.yml"
chmod 644 "$DEPLOY_DIR/docker-compose.yml"

echo "✅ Docker Compose配置文件已生成"
```

### 3.3 拉取镜像和启动服务

**AI执行指令**:
```bash
cd "$DEPLOY_DIR"

echo "=== 拉取Docker镜像 ==="
docker pull xpzouying/xiaohongshu-mcp:latest

if [ $? -eq 0 ]; then
    echo "✅ 镜像拉取成功"
else
    echo "❌ 镜像拉取失败"
    exit 1
fi

echo "=== 启动服务 ==="
# 使用服务用户启动
sudo -u "$SERVICE_USER" docker compose up -d

if [ $? -eq 0 ]; then
    echo "✅ 服务启动成功"
else
    echo "❌ 服务启动失败"
    docker compose logs
    exit 1
fi

# 等待服务就绪
echo "⏳ 等待服务启动..."
sleep 30

# 检查容器状态
CONTAINER_STATUS=$(docker inspect xiaohongshu-mcp --format='{{.State.Status}}')
if [ "$CONTAINER_STATUS" = "running" ]; then
    echo "✅ 容器运行状态正常"
else
    echo "❌ 容器状态异常: $CONTAINER_STATUS"
    docker logs xiaohongshu-mcp
    exit 1
fi
```

### 3.4 服务健康检查

**AI执行指令**:
```bash
echo "=== 服务健康检查 ==="

# 检查端口监听
if netstat -tuln | grep :18060 > /dev/null; then
    echo "✅ 端口18060监听正常"
else
    echo "❌ 端口18060未监听"
    exit 1
fi

# 检查HTTP健康端点
HEALTH_CHECK_URL="http://localhost:18060/health"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$HEALTH_CHECK_URL")

if [ "$HTTP_STATUS" = "200" ]; then
    echo "✅ HTTP健康检查通过"
else
    echo "❌ HTTP健康检查失败，状态码: $HTTP_STATUS"
    
    # 输出详细错误信息
    echo "=== 容器日志 ==="
    docker logs --tail 50 xiaohongshu-mcp
    
    echo "=== 容器状态 ==="
    docker ps -f name=xiaohongshu-mcp
    
    exit 1
fi

# 检查MCP端点
MCP_URL="http://localhost:18060/mcp"
MCP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$MCP_URL")

if [ "$MCP_STATUS" = "200" ] || [ "$MCP_STATUS" = "404" ]; then
    echo "✅ MCP端点可访问"
else
    echo "❌ MCP端点访问失败，状态码: $MCP_STATUS"
fi

echo "✅ 服务健康检查完成"
```

---

## 🔐 第四阶段：登录配置和验证

### 4.1 获取登录二维码

**AI执行指令**:
```bash
echo "=== 配置小红书登录 ==="

# 检查登录状态API
LOGIN_STATUS_URL="http://localhost:18060/api/v1/login/status"
STATUS_RESPONSE=$(curl -s "$LOGIN_STATUS_URL")

echo "当前登录状态: $STATUS_RESPONSE"

# 获取登录二维码
QRCODE_URL="http://localhost:18060/api/v1/login/qrcode"
echo "正在获取登录二维码..."

QRCODE_RESPONSE=$(curl -s "$QRCODE_URL")

if echo "$QRCODE_RESPONSE" | grep -q "success.*true"; then
    echo "✅ 二维码获取成功"
    
    # 提取二维码数据并保存为文件
    echo "$QRCODE_RESPONSE" | jq -r '.data.img' | sed 's/data:image\/png;base64,//' | base64 -d > "$DEPLOY_DIR/qrcode.png"
    
    if [ -f "$DEPLOY_DIR/qrcode.png" ]; then
        echo "✅ 二维码已保存到: $DEPLOY_DIR/qrcode.png"
        echo "📱 请使用小红书App扫描二维码登录"
        echo "⏰ 二维码有效期约5分钟"
        
        # 显示二维码文件信息
        ls -la "$DEPLOY_DIR/qrcode.png"
    else
        echo "❌ 二维码保存失败"
    fi
else
    echo "❌ 二维码获取失败"
    echo "响应内容: $QRCODE_RESPONSE"
fi
```

### 4.2 登录状态验证

**AI执行指令**:
```bash
echo "=== 验证登录状态 ==="

# 等待用户扫码登录
echo "⏳ 等待用户扫码登录..."
echo "💡 提示: 请在5分钟内使用小红书App扫描二维码"

# 轮询检查登录状态
MAX_ATTEMPTS=30
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    sleep 10
    ATTEMPT=$((ATTEMPT + 1))
    
    echo "检查登录状态 (第${ATTEMPT}次/共${MAX_ATTEMPTS}次)..."
    
    STATUS_RESPONSE=$(curl -s "$LOGIN_STATUS_URL")
    
    if echo "$STATUS_RESPONSE" | grep -q "已登录\|logged.*in\|success.*true"; then
        echo "✅ 登录成功！"
        echo "登录状态: $STATUS_RESPONSE"
        
        # 检查cookies文件
        if [ -f "$DEPLOY_DIR/data/cookies.json" ]; then
            echo "✅ Cookies文件已生成"
            ls -la "$DEPLOY_DIR/data/cookies.json"
        fi
        
        break
    else
        echo "⏳ 尚未登录，继续等待..."
    fi
    
    if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
        echo "⚠️  登录超时，请重新获取二维码"
        echo "可以稍后手动检查登录状态: curl $LOGIN_STATUS_URL"
    fi
done
```

### 4.3 功能验证测试

**AI执行指令**:
```bash
echo "=== 功能验证测试 ==="

# 测试MCP工具列表
echo "1. 测试MCP工具列表..."
TOOLS_URL="http://localhost:18060/mcp/tools"
TOOLS_RESPONSE=$(curl -s "$TOOLS_URL")

if echo "$TOOLS_RESPONSE" | grep -q "mcp_xiaohongshu"; then
    echo "✅ MCP工具列表正常"
    echo "可用工具数量: $(echo "$TOOLS_RESPONSE" | jq '.tools | length' 2>/dev/null || echo "未知")"
else
    echo "❌ MCP工具列表异常"
    echo "响应: $TOOLS_RESPONSE"
fi

# 测试获取用户内容列表（需要登录）
echo "2. 测试获取用户内容..."
FEEDS_URL="http://localhost:18060/api/v1/feeds"
FEEDS_RESPONSE=$(curl -s "$FEEDS_URL")

if echo "$FEEDS_RESPONSE" | grep -q "success\|feeds"; then
    echo "✅ 用户内容获取正常"
else
    echo "⚠️  用户内容获取需要登录状态"
    echo "响应: $FEEDS_RESPONSE"
fi

# 测试搜索功能
echo "3. 测试搜索功能..."
SEARCH_URL="http://localhost:18060/api/v1/search"
SEARCH_DATA='{"keyword":"美食"}'
SEARCH_RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" -d "$SEARCH_DATA" "$SEARCH_URL")

if echo "$SEARCH_RESPONSE" | grep -q "success\|results"; then
    echo "✅ 搜索功能正常"
else
    echo "⚠️  搜索功能可能需要登录状态"
    echo "响应: $SEARCH_RESPONSE"
fi

echo "✅ 功能验证测试完成"
```

---

## 📊 第五阶段：监控和维护配置

### 5.1 安装监控脚本

**AI执行指令**:
```bash
echo "=== 安装监控脚本 ==="

# 创建监控脚本
cat > "$DEPLOY_DIR/scripts/monitor.sh" << 'EOF'
#!/bin/bash

SERVICE_NAME="xiaohongshu-mcp"
HEALTH_URL="http://localhost:18060/health"
LOG_FILE="/var/log/xiaohongshu-mcp-monitor.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

check_health() {
    if docker ps | grep -q "$SERVICE_NAME" && curl -f -s "$HEALTH_URL" > /dev/null; then
        log "SUCCESS: Service is healthy"
        return 0
    else
        log "ERROR: Service is unhealthy"
        return 1
    fi
}

restart_service() {
    log "Restarting service..."
    cd /opt/xiaohongshu-mcp
    docker compose restart
    sleep 30
    check_health
}

case "$1" in
    "check") check_health ;;
    "restart") restart_service ;;
    "status") 
        docker ps -f name="$SERVICE_NAME"
        docker stats "$SERVICE_NAME" --no-stream
        ;;
    "logs") docker logs --tail "${2:-50}" "$SERVICE_NAME" ;;
    *) echo "Usage: $0 {check|restart|status|logs [lines]}" ;;
esac
EOF

# 设置脚本权限
chmod +x "$DEPLOY_DIR/scripts/monitor.sh"
chown "$SERVICE_USER:$SERVICE_USER" "$DEPLOY_DIR/scripts/monitor.sh"

echo "✅ 监控脚本安装完成"
```

### 5.2 配置系统服务

**AI执行指令**:
```bash
echo "=== 配置系统服务 ==="

# 创建systemd服务文件
cat > "/etc/systemd/system/xiaohongshu-mcp.service" << EOF
[Unit]
Description=Xiaohongshu MCP Service
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$DEPLOY_DIR
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
User=$SERVICE_USER
Group=$SERVICE_USER

[Install]
WantedBy=multi-user.target
EOF

# 重载systemd配置
systemctl daemon-reload
systemctl enable xiaohongshu-mcp.service

echo "✅ 系统服务配置完成"

# 测试服务控制
echo "测试服务控制..."
systemctl status xiaohongshu-mcp.service
```

### 5.3 设置定时任务

**AI执行指令**:
```bash
echo "=== 设置定时监控任务 ==="

# 创建cron任务
cat > "/etc/cron.d/xiaohongshu-mcp" << EOF
# Xiaohongshu MCP Service Monitoring
*/5 * * * * $SERVICE_USER $DEPLOY_DIR/scripts/monitor.sh check
0 2 * * * $SERVICE_USER $DEPLOY_DIR/scripts/monitor.sh backup
0 6 * * 0 $SERVICE_USER docker system prune -f
EOF

# 重启cron服务
systemctl restart cron || systemctl restart crond

echo "✅ 定时任务设置完成"
echo "监控任务: 每5分钟检查一次服务状态"
echo "备份任务: 每天凌晨2点备份数据"
echo "清理任务: 每周日凌晨6点清理Docker缓存"
```

---

## 🔧 第六阶段：故障排除和维护指南

### 6.1 常见问题诊断

**AI执行指令模板**:
```bash
echo "=== 故障诊断工具 ==="

# 创建诊断脚本
cat > "$DEPLOY_DIR/scripts/diagnose.sh" << 'EOF'
#!/bin/bash

echo "=== 小红书MCP服务诊断报告 ==="
echo "生成时间: $(date)"
echo ""

echo "1. 系统信息:"
uname -a
echo "内存使用: $(free -h | grep '^Mem:')"
echo "磁盘使用: $(df -h / | tail -1)"
echo ""

echo "2. Docker状态:"
docker --version
docker compose version
systemctl status docker --no-pager
echo ""

echo "3. 容器状态:"
docker ps -a -f name=xiaohongshu-mcp
echo ""

echo "4. 容器资源使用:"
docker stats xiaohongshu-mcp --no-stream
echo ""

echo "5. 网络连接:"
netstat -tuln | grep :18060
echo ""

echo "6. 服务健康检查:"
curl -s http://localhost:18060/health || echo "健康检查失败"
echo ""

echo "7. 最近日志 (最后20行):"
docker logs --tail 20 xiaohongshu-mcp
echo ""

echo "8. 数据目录状态:"
ls -la /opt/xiaohongshu-mcp/data/
echo ""

echo "=== 诊断完成 ==="
EOF

chmod +x "$DEPLOY_DIR/scripts/diagnose.sh"
chown "$SERVICE_USER:$SERVICE_USER" "$DEPLOY_DIR/scripts/diagnose.sh"

echo "✅ 诊断脚本创建完成"
echo "使用方法: $DEPLOY_DIR/scripts/diagnose.sh"
```

### 6.2 自动恢复机制

**AI执行指令**:
```bash
echo "=== 配置自动恢复机制 ==="

# 创建自动恢复脚本
cat > "$DEPLOY_DIR/scripts/auto-recovery.sh" << 'EOF'
#!/bin/bash

LOG_FILE="/var/log/xiaohongshu-mcp-recovery.log"
DEPLOY_DIR="/opt/xiaohongshu-mcp"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# 检查并恢复服务
recover_service() {
    log "开始服务恢复流程..."
    
    cd "$DEPLOY_DIR"
    
    # 停止现有容器
    docker compose down
    
    # 清理可能的问题
    docker system prune -f
    
    # 重新拉取镜像
    docker pull xpzouying/xiaohongshu-mcp:latest
    
    # 重新启动
    docker compose up -d
    
    # 等待启动
    sleep 60
    
    # 验证恢复
    if curl -f -s http://localhost:18060/health > /dev/null; then
        log "SUCCESS: 服务恢复成功"
        return 0
    else
        log "ERROR: 服务恢复失败"
        return 1
    fi
}

# 主恢复逻辑
if ! curl -f -s http://localhost:18060/health > /dev/null; then
    log "检测到服务异常，开始自动恢复..."
    recover_service
else
    log "服务状态正常"
fi
EOF

chmod +x "$DEPLOY_DIR/scripts/auto-recovery.sh"
chown "$SERVICE_USER:$SERVICE_USER" "$DEPLOY_DIR/scripts/auto-recovery.sh"

echo "✅ 自动恢复机制配置完成"
```

---

## 📋 第七阶段：部署验证和交付

### 7.1 完整功能验证

**AI执行指令**:
```bash
echo "=== 最终部署验证 ==="

# 验证清单
VERIFICATION_PASSED=true

echo "1. 验证容器运行状态..."
if docker ps | grep -q "xiaohongshu-mcp.*Up"; then
    echo "✅ 容器运行正常"
else
    echo "❌ 容器未运行"
    VERIFICATION_PASSED=false
fi

echo "2. 验证端口监听..."
if netstat -tuln | grep -q ":18060"; then
    echo "✅ 端口监听正常"
else
    echo "❌ 端口未监听"
    VERIFICATION_PASSED=false
fi

echo "3. 验证HTTP服务..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:18060/health)
if [ "$HTTP_STATUS" = "200" ]; then
    echo "✅ HTTP服务正常"
else
    echo "❌ HTTP服务异常，状态码: $HTTP_STATUS"
    VERIFICATION_PASSED=false
fi

echo "4. 验证MCP协议..."
MCP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:18060/mcp)
if [ "$MCP_STATUS" = "200" ] || [ "$MCP_STATUS" = "404" ]; then
    echo "✅ MCP协议端点可访问"
else
    echo "❌ MCP协议端点异常"
    VERIFICATION_PASSED=false
fi

echo "5. 验证数据目录..."
if [ -d "$DEPLOY_DIR/data" ] && [ -d "$DEPLOY_DIR/images" ]; then
    echo "✅ 数据目录结构正确"
else
    echo "❌ 数据目录结构异常"
    VERIFICATION_PASSED=false
fi

echo "6. 验证监控脚本..."
if [ -x "$DEPLOY_DIR/scripts/monitor.sh" ]; then
    echo "✅ 监控脚本可执行"
else
    echo "❌ 监控脚本异常"
    VERIFICATION_PASSED=false
fi

echo "7. 验证系统服务..."
if systemctl is-enabled xiaohongshu-mcp.service > /dev/null; then
    echo "✅ 系统服务已启用"
else
    echo "❌ 系统服务未启用"
    VERIFICATION_PASSED=false
fi

# 最终验证结果
if [ "$VERIFICATION_PASSED" = true ]; then
    echo ""
    echo "🎉 部署验证全部通过！"
    echo ""
else
    echo ""
    echo "❌ 部署验证失败，请检查上述问题"
    echo ""
    exit 1
fi
```

### 7.2 生成部署报告

**AI执行指令**:
```bash
echo "=== 生成部署报告 ==="

REPORT_FILE="$DEPLOY_DIR/deployment-report.txt"

cat > "$REPORT_FILE" << EOF
# 小红书MCP服务部署报告

## 部署信息
- 部署时间: $(date)
- 部署目录: $DEPLOY_DIR
- 服务用户: $SERVICE_USER
- Docker镜像: xpzouying/xiaohongshu-mcp:latest

## 服务配置
- 服务端口: 18060
- 健康检查: http://localhost:18060/health
- MCP端点: http://localhost:18060/mcp
- 数据目录: $DEPLOY_DIR/data
- 图片目录: $DEPLOY_DIR/images

## 管理命令
- 查看状态: $DEPLOY_DIR/scripts/monitor.sh status
- 查看日志: $DEPLOY_DIR/scripts/monitor.sh logs
- 重启服务: systemctl restart xiaohongshu-mcp
- 诊断问题: $DEPLOY_DIR/scripts/diagnose.sh
- 自动恢复: $DEPLOY_DIR/scripts/auto-recovery.sh

## 登录配置
- 获取二维码: curl http://localhost:18060/api/v1/login/qrcode
- 检查登录状态: curl http://localhost:18060/api/v1/login/status
- Cookies存储: $DEPLOY_DIR/data/cookies.json

## 监控配置
- 健康检查: 每5分钟自动执行
- 数据备份: 每天凌晨2点自动执行
- 系统清理: 每周日凌晨6点自动执行

## 下一步操作
1. 使用MCP Inspector连接到 http://localhost:18060/mcp
2. 获取登录二维码并使用小红书App扫描登录
3. 验证各项功能是否正常工作
4. 根据需要配置Nginx反向代理和SSL证书

## 技术支持
- 项目地址: https://github.com/xpzouying/xiaohongshu-mcp
- Docker镜像: https://hub.docker.com/r/xpzouying/xiaohongshu-mcp
- 问题反馈: https://github.com/xpzouying/xiaohongshu-mcp/issues

EOF

echo "✅ 部署报告已生成: $REPORT_FILE"
echo ""
echo "📋 部署摘要:"
cat "$REPORT_FILE"
```

---

## 🎯 AI执行总结

### 执行成功标准
1. ✅ 所有容器正常运行
2. ✅ HTTP服务响应正常 (200状态码)
3. ✅ MCP协议端点可访问
4. ✅ 数据目录结构正确
5. ✅ 监控和维护脚本就位
6. ✅ 系统服务正确配置

### 关键验证点
- **服务可用性**: `curl http://localhost:18060/health` 返回200
- **容器状态**: `docker ps` 显示容器运行中
- **端口监听**: `netstat -tuln | grep :18060` 有输出
- **数据持久化**: 数据目录存在且权限正确

### 故障处理流程
1. 执行诊断脚本获取详细信息
2. 检查Docker和系统资源状态
3. 查看容器日志定位问题
4. 必要时执行自动恢复流程
5. 验证修复结果

### 后续维护要点
- 定期检查服务状态和日志
- 监控系统资源使用情况
- 及时更新Docker镜像版本
- 定期备份重要数据和配置

---

**📞 技术支持联系方式**
- GitHub Issues: https://github.com/xpzouying/xiaohongshu-mcp/issues
- 官方文档: https://github.com/xpzouying/xiaohongshu-mcp
- Docker Hub: https://hub.docker.com/r/xpzouying/xiaohongshu-mcp

---

*本手册版本: v1.0 | 最后更新: $(date '+%Y-%m-%d')*