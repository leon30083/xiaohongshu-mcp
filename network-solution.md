# 小红书MCP服务网络配置完整解决方案

## 🌐 当前网络拓扑分析

```
Internet (无固定IP)
    ↓
主路由器 (DHCP获取公网IP)
    ↓
二级路由器 (10.168.1.1)
    ├── Windows PC (10.168.1.109) - MCP代理服务器:8080
    └── Linux ARM64 (10.168.1.128) - Nginx反向代理:8080
```

## 🔧 解决方案1：双层路由端口映射

### 步骤1：二级路由器配置
1. 登录二级路由器 (10.168.1.1)
2. 设置端口映射：
   ```
   外部端口：8080
   内部IP：10.168.1.128 (Linux服务器)
   内部端口：8080
   协议：TCP
   ```

### 步骤2：主路由器配置
1. 登录主路由器管理界面
2. 找到二级路由器的IP地址（通常是192.168.1.x）
3. 设置端口映射：
   ```
   外部端口：8080
   内部IP：[二级路由器IP]
   内部端口：8080
   协议：TCP
   ```

## 🚀 解决方案2：内网穿透服务（推荐）

由于您没有固定IP，使用内网穿透是最佳选择：

### 方案A：Cloudflare Tunnel（免费，推荐）

#### 1. 在Linux服务器上安装cloudflared
```bash
# 下载cloudflared
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64
chmod +x cloudflared-linux-arm64
sudo mv cloudflared-linux-arm64 /usr/local/bin/cloudflared

# 验证安装
cloudflared --version
```

#### 2. 登录Cloudflare
```bash
cloudflared tunnel login
```

#### 3. 创建隧道
```bash
# 创建隧道
cloudflared tunnel create xiaohongshu-mcp

# 配置隧道
sudo mkdir -p /etc/cloudflared
sudo nano /etc/cloudflared/config.yml
```

#### 4. 配置文件内容
```yaml
tunnel: xiaohongshu-mcp
credentials-file: /root/.cloudflared/[tunnel-id].json

ingress:
  - hostname: your-domain.com
    service: http://localhost:8080
  - service: http_status:404
```

#### 5. 启动隧道
```bash
# 测试运行
cloudflared tunnel run xiaohongshu-mcp

# 设置为系统服务
sudo cloudflared service install
sudo systemctl enable cloudflared
sudo systemctl start cloudflared
```

### 方案B：frp内网穿透

#### 1. 在Linux服务器上配置frp客户端
```bash
# 下载frp
wget https://github.com/fatedier/frp/releases/download/v0.52.3/frp_0.52.3_linux_arm64.tar.gz
tar -xzf frp_0.52.3_linux_arm64.tar.gz
cd frp_0.52.3_linux_arm64

# 配置客户端
nano frpc.ini
```

#### 2. frpc.ini配置
```ini
[common]
server_addr = frp.example.com  # 使用公共frp服务器
server_port = 7000
token = your_token

[xiaohongshu-mcp]
type = http
local_ip = 127.0.0.1
local_port = 8080
custom_domains = your-subdomain.frp.example.com
```

#### 3. 启动frp客户端
```bash
./frpc -c frpc.ini
```

### 方案C：ngrok（简单易用）

#### 1. 安装ngrok
```bash
# 下载ngrok
wget https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-arm64.tgz
tar -xzf ngrok-v3-stable-linux-arm64.tgz
sudo mv ngrok /usr/local/bin/

# 配置认证
ngrok config add-authtoken YOUR_AUTHTOKEN
```

#### 2. 启动隧道
```bash
ngrok http 8080
```

## 🔄 自动化脚本

### 创建启动脚本
```bash
sudo nano /usr/local/bin/start-xiaohongshu-tunnel.sh
```

```bash
#!/bin/bash
# 小红书MCP服务隧道启动脚本

echo "🚀 启动小红书MCP服务隧道..."

# 检查Nginx状态
if ! systemctl is-active --quiet nginx; then
    echo "启动Nginx..."
    sudo systemctl start nginx
fi

# 启动Cloudflare隧道
if command -v cloudflared &> /dev/null; then
    echo "启动Cloudflare隧道..."
    cloudflared tunnel run xiaohongshu-mcp &
elif command -v ngrok &> /dev/null; then
    echo "启动ngrok隧道..."
    ngrok http 8080 &
else
    echo "❌ 未找到隧道工具，请先安装cloudflared或ngrok"
    exit 1
fi

echo "✅ 隧道启动完成！"
```

```bash
chmod +x /usr/local/bin/start-xiaohongshu-tunnel.sh
```

## 📊 监控和管理

### 创建状态检查脚本
```bash
sudo nano /usr/local/bin/check-xiaohongshu-status.sh
```

```bash
#!/bin/bash
# 服务状态检查脚本

echo "=== 小红书MCP服务状态 ==="
echo "时间: $(date)"
echo

# 检查Nginx
echo "🔍 Nginx状态:"
systemctl is-active nginx && echo "✅ 运行中" || echo "❌ 停止"

# 检查端口
echo "🔍 端口8080状态:"
netstat -tlnp | grep :8080 && echo "✅ 监听中" || echo "❌ 未监听"

# 检查隧道
echo "🔍 隧道状态:"
if pgrep -f cloudflared > /dev/null; then
    echo "✅ Cloudflare隧道运行中"
elif pgrep -f ngrok > /dev/null; then
    echo "✅ ngrok隧道运行中"
else
    echo "❌ 隧道未运行"
fi

# 测试本地连接
echo "🔍 本地服务测试:"
curl -s http://localhost:8080/health > /dev/null && echo "✅ 本地服务正常" || echo "❌ 本地服务异常"
```

```bash
chmod +x /usr/local/bin/check-xiaohongshu-status.sh
```

## 🎯 推荐配置流程

1. **首选方案**：使用Cloudflare Tunnel
   - 免费且稳定
   - 自动SSL证书
   - 全球CDN加速

2. **备选方案**：配置双层路由映射
   - 适合有路由器管理权限的情况
   - 需要动态DNS服务

3. **临时方案**：使用ngrok
   - 快速测试
   - 付费版本更稳定

## 🔧 故障排除

### 常见问题
1. **端口冲突**：检查8080端口是否被占用
2. **防火墙**：确保Linux服务器防火墙允许8080端口
3. **网络连通性**：测试Windows PC到Linux服务器的连接
4. **隧道断开**：设置自动重连机制

### 调试命令
```bash
# 检查端口占用
netstat -tlnp | grep 8080

# 检查防火墙
sudo ufw status

# 测试内网连接
curl -i http://10.168.1.109:8080/health

# 查看Nginx日志
sudo tail -f /var/log/nginx/access.log
```

选择最适合您环境的方案，我可以帮您具体实施配置！