# 小红书MCP服务 Docker部署完整指南

## 🎯 部署概述

本指南将帮助您在Linux服务器上使用Docker快速部署小红书MCP服务，实现无头模式运行。

## 📋 前置要求

- Linux服务器（Ubuntu 18.04+ / CentOS 7+ / Debian 9+）
- Docker 20.10+
- Docker Compose 2.0+
- 至少2GB内存
- 至少5GB磁盘空间

## 🚀 快速部署

### 方案一：使用官方镜像（推荐）

#### 1. 创建项目目录
```bash
mkdir -p ~/xiaohongshu-mcp
cd ~/xiaohongshu-mcp
```

#### 2. 创建docker-compose.yml
```yaml
services:
  xiaohongshu-mcp:
    image: xpzouying/xiaohongshu-mcp:latest
    container_name: xiaohongshu-mcp
    restart: unless-stopped
    tty: true
    volumes:
      - ./data:/app/data
      - ./images:/app/images
    environment:
      - ROD_BROWSER_BIN=/usr/bin/google-chrome
      - COOKIES_PATH=/app/data/cookies.json
    ports:
      - "18060:18060"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:18060/health"]
      interval: 30s
      timeout: 10s
      retries: 3
```

#### 3. 启动服务
```bash
# 拉取最新镜像
docker pull xpzouying/xiaohongshu-mcp:latest

# 启动服务
docker compose up -d

# 查看日志
docker compose logs -f
```

#### 4. 验证部署
```bash
# 检查容器状态
docker ps

# 检查服务健康状态
curl http://localhost:18060/health

# 查看实时日志
docker logs -f xiaohongshu-mcp
```

### 方案二：自建镜像

#### 1. 克隆源码
```bash
git clone https://github.com/xpzouying/xiaohongshu-mcp.git
cd xiaohongshu-mcp
```

#### 2. 构建镜像
```bash
docker build -t xiaohongshu-mcp:local .
```

#### 3. 修改docker-compose.yml
```yaml
services:
  xiaohongshu-mcp:
    image: xiaohongshu-mcp:local  # 使用本地构建的镜像
    # ... 其他配置同上
```

## 🔐 登录配置

### 获取登录二维码

#### 方法1：使用MCP Inspector
```bash
# 安装MCP Inspector
npm install -g @modelcontextprotocol/inspector

# 启动Inspector
npx @modelcontextprotocol/inspector

# 在浏览器中访问：http://your-server-ip:3000
# 连接到：http://your-server-ip:18060/mcp
```

#### 方法2：使用HTTP API
```bash
# 获取二维码
curl -X GET http://your-server-ip:18060/api/v1/login/qrcode

# 响应示例
{
  "success": true,
  "data": {
    "timeout": 300,
    "img": "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA..."
  },
  "message": "获取登录二维码成功"
}
```

#### 方法3：保存二维码到文件
```bash
# 获取二维码并保存为图片
curl -s http://your-server-ip:18060/api/v1/login/qrcode | \
  jq -r '.data.img' | \
  sed 's/data:image\/png;base64,//' | \
  base64 -d > qrcode.png

# 下载到本地查看
scp user@your-server-ip:~/qrcode.png ./
```

### 检查登录状态
```bash
# 检查是否已登录
curl -X GET http://your-server-ip:18060/api/v1/login/status
```

## 🔧 高级配置

### 环境变量配置
```yaml
environment:
  - ROD_BROWSER_BIN=/usr/bin/google-chrome
  - COOKIES_PATH=/app/data/cookies.json
  - LOG_LEVEL=info
  - PORT=18060
  - HEADLESS=true
```

### 数据持久化
```yaml
volumes:
  - ./data:/app/data              # 存储cookies和配置
  - ./images:/app/images          # 存储上传的图片
  - ./logs:/app/logs              # 存储日志文件（可选）
```

### 网络配置
```yaml
networks:
  xiaohongshu-net:
    driver: bridge

services:
  xiaohongshu-mcp:
    networks:
      - xiaohongshu-net
```

## 🛡️ 生产环境优化

### 1. 反向代理配置（Nginx）
```nginx
server {
    listen 80;
    server_name your-domain.com;
    
    location / {
        proxy_pass http://localhost:18060;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### 2. SSL证书配置
```bash
# 使用Let's Encrypt
certbot --nginx -d your-domain.com
```

### 3. 防火墙配置
```bash
# 只允许必要端口
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw enable
```

### 4. 资源限制
```yaml
services:
  xiaohongshu-mcp:
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 2G
        reservations:
          cpus: '0.5'
          memory: 1G
```

## 📊 监控和日志

### 日志管理
```bash
# 查看实时日志
docker logs -f xiaohongshu-mcp

# 查看最近100行日志
docker logs --tail 100 xiaohongshu-mcp

# 导出日志到文件
docker logs xiaohongshu-mcp > app.log 2>&1
```

### 健康检查
```bash
# 检查容器健康状态
docker inspect xiaohongshu-mcp | jq '.[0].State.Health'

# 自定义健康检查脚本
#!/bin/bash
response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:18060/health)
if [ $response -eq 200 ]; then
    echo "Service is healthy"
    exit 0
else
    echo "Service is unhealthy"
    exit 1
fi
```

## 🔄 维护操作

### 更新服务
```bash
# 拉取最新镜像
docker pull xpzouying/xiaohongshu-mcp:latest

# 重启服务
docker compose pull && docker compose up -d
```

### 备份数据
```bash
# 备份数据目录
tar -czf xiaohongshu-backup-$(date +%Y%m%d).tar.gz data/ images/

# 备份到远程
rsync -av data/ user@backup-server:/backup/xiaohongshu/data/
```

### 故障排除
```bash
# 查看容器状态
docker ps -a

# 进入容器调试
docker exec -it xiaohongshu-mcp bash

# 重启服务
docker compose restart

# 查看系统资源使用
docker stats xiaohongshu-mcp
```

## 🚨 常见问题

### Q1: 容器启动失败
```bash
# 检查日志
docker logs xiaohongshu-mcp

# 常见原因：
# 1. 端口被占用
# 2. 权限不足
# 3. 内存不足
```

### Q2: 无法获取二维码
```bash
# 检查Chrome是否正常安装
docker exec -it xiaohongshu-mcp google-chrome --version

# 检查无头模式配置
docker exec -it xiaohongshu-mcp env | grep ROD_BROWSER_BIN
```

### Q3: 登录状态丢失
```bash
# 检查cookies文件
docker exec -it xiaohongshu-mcp ls -la /app/data/

# 重新登录
curl -X POST http://localhost:18060/api/v1/login
```

## 📞 技术支持

- GitHub Issues: https://github.com/xpzouying/xiaohongshu-mcp/issues
- 官方文档: https://github.com/xpzouying/xiaohongshu-mcp
- Docker Hub: https://hub.docker.com/r/xpzouying/xiaohongshu-mcp

---

**部署完成后，您的小红书MCP服务将在 `http://your-server-ip:18060` 上运行！**