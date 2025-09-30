# 混合架构部署和测试指南

## 📋 概述

本指南详细说明如何部署混合架构，实现云端 Dify 调用本地 Xiaohongshu MCP 服务。

## 🏗️ 架构图

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   云端 Dify     │    │   内网穿透      │    │   本地环境      │
│                 │    │                 │    │                 │
│  ┌───────────┐  │    │  ┌───────────┐  │    │  ┌───────────┐  │
│  │   Agent   │──┼────┼──│  Tunnel   │──┼────┼──│MCP Proxy  │  │
│  └───────────┘  │    │  └───────────┘  │    │  └───────────┘  │
│                 │    │                 │    │        │        │
└─────────────────┘    └─────────────────┘    │  ┌───────────┐  │
                                              │  │Local MCP  │  │
                                              │  └───────────┘  │
                                              │        │        │
                                              │  ┌───────────┐  │
                                              │  │ Browser   │  │
                                              │  └───────────┘  │
                                              └─────────────────┘
```

## 🚀 部署步骤

### Phase 1: 本地环境准备

#### 1.1 启动本地 MCP 服务

```powershell
# 切换到本地 MCP 模式
.\切换到本地MCP.ps1 -SwitchToLocal

# 启动本地 MCP 服务
cd xiaohongshu-mcp
npm start
```

#### 1.2 启动 MCP 代理服务器

```powershell
# 安装依赖
npm install

# 启动代理服务器
npm start
# 或者
node mcp-proxy-server.js
```

验证代理服务器：
```powershell
# 检查端口 8080 是否监听
netstat -an | findstr :8080

# 测试代理服务器
curl http://localhost:8080/health
```

### Phase 2: 选择内网穿透方案

#### 方案对比

| 方案 | 难度 | 费用 | 稳定性 | 推荐场景 |
|------|------|------|--------|----------|
| **Ngrok** | ⭐ | 免费/付费 | ⭐⭐⭐ | 快速测试 |
| **Cloudflare Tunnel** | ⭐⭐ | 免费 | ⭐⭐⭐⭐⭐ | 生产环境 |
| **FRP** | ⭐⭐⭐⭐ | 需服务器 | ⭐⭐⭐⭐⭐ | 企业用户 |
| **Tailscale Funnel** | ⭐⭐⭐ | 免费 | ⭐⭐⭐⭐⭐ | 已有Tailscale |

#### 2.1 方案一：Ngrok（推荐新手）

```powershell
# 使用统一管理工具
.\tunnel-solutions\tunnel-manager.ps1 -Method ngrok -Action install
.\tunnel-solutions\tunnel-manager.ps1 -Method ngrok -Action start

# 或直接使用 Ngrok 脚本
.\tunnel-solutions\ngrok-setup.ps1 -Install
.\tunnel-solutions\ngrok-setup.ps1 -Start
```

#### 2.2 方案二：Cloudflare Tunnel（推荐生产）

```powershell
# 安装 Cloudflared
.\tunnel-solutions\cloudflare-tunnel.ps1 -Install

# 登录 Cloudflare 账号
.\tunnel-solutions\cloudflare-tunnel.ps1 -Login

# 创建隧道
.\tunnel-solutions\cloudflare-tunnel.ps1 -Create

# 启动隧道
.\tunnel-solutions\cloudflare-tunnel.ps1 -Start
```

#### 2.3 方案三：FRP（高级用户）

```powershell
# 安装 FRP 客户端
.\tunnel-solutions\frp-setup.ps1 -Install

# 配置 FRP（需要自己的服务器）
.\tunnel-solutions\frp-setup.ps1 -Setup -ServerIP "your-server-ip" -Token "your-token"

# 启动 FRP 客户端
.\tunnel-solutions\frp-setup.ps1 -Start
```

#### 2.4 方案四：Tailscale Funnel（已有Tailscale）

```powershell
# 配置 Tailscale Funnel
.\tunnel-solutions\tailscale-funnel.ps1 -Setup

# 启动 Funnel
.\tunnel-solutions\tailscale-funnel.ps1 -Start
```

### Phase 3: 配置云端 Dify

#### 3.1 获取公网访问地址

根据选择的内网穿透方案，获取公网访问地址：

- **Ngrok**: `https://xxxxx.ngrok.io`
- **Cloudflare**: `https://your-tunnel.trycloudflare.com`
- **FRP**: `http://your-server-ip:port`
- **Tailscale**: `https://your-device.tailscale.net`

#### 3.2 在 Dify 中配置 MCP 服务

1. 登录云端 Dify 管理界面
2. 进入 "工具" 或 "插件" 设置
3. 添加新的 MCP 服务：
   ```
   服务名称: Xiaohongshu MCP
   服务地址: https://your-tunnel-url
   健康检查: https://your-tunnel-url/health
   ```

#### 3.3 配置 Agent

在 Dify Agent 中添加 Xiaohongshu MCP 工具：

```json
{
  "name": "xiaohongshu_mcp",
  "description": "小红书内容管理工具",
  "endpoint": "https://your-tunnel-url",
  "methods": [
    "mcp_xiaohongshu-mcp_check_login_status",
    "mcp_xiaohongshu-mcp_get_login_qrcode",
    "mcp_xiaohongshu-mcp_publish_content",
    "mcp_xiaohongshu-mcp_search_feeds"
  ]
}
```

## 🧪 测试验证

### 测试清单

#### ✅ 本地环境测试

```powershell
# 1. 测试本地 MCP 服务
curl http://localhost:3000/health

# 2. 测试代理服务器
curl http://localhost:8080/health

# 3. 测试代理转发
curl http://localhost:8080/mcp/check_login_status
```

#### ✅ 内网穿透测试

```powershell
# 1. 检查隧道状态
.\tunnel-solutions\tunnel-manager.ps1 -Method <your-method> -Action status

# 2. 测试公网访问
curl https://your-tunnel-url/health

# 3. 测试 MCP 接口
curl https://your-tunnel-url/mcp/check_login_status
```

#### ✅ Dify 集成测试

1. **连接测试**
   - 在 Dify 中测试 MCP 服务连接
   - 验证健康检查接口响应

2. **功能测试**
   - 测试登录状态检查
   - 测试二维码获取
   - 测试内容发布（如果已登录）

3. **性能测试**
   - 测试响应时间
   - 测试并发请求
   - 测试稳定性

### 常见问题排查

#### 🔧 本地服务问题

```powershell
# 检查端口占用
netstat -an | findstr :3000
netstat -an | findstr :8080

# 检查进程
Get-Process -Name "node" -ErrorAction SilentlyContinue

# 重启服务
# 停止所有 Node.js 进程
Get-Process -Name "node" | Stop-Process -Force
# 重新启动
npm start
```

#### 🔧 内网穿透问题

```powershell
# 检查网络连接
Test-NetConnection -ComputerName "8.8.8.8" -Port 53

# 检查防火墙
Get-NetFirewallRule -DisplayName "*ngrok*" -ErrorAction SilentlyContinue

# 重置隧道
.\tunnel-solutions\tunnel-manager.ps1 -Method <method> -Action stop
.\tunnel-solutions\tunnel-manager.ps1 -Method <method> -Action start
```

#### 🔧 Dify 连接问题

1. **检查 URL 格式**
   - 确保使用 HTTPS（除非是 FRP）
   - 确保 URL 末尾没有多余的斜杠

2. **检查网络策略**
   - 确保 Dify 服务器可以访问公网
   - 检查是否有防火墙限制

3. **检查认证**
   - 确保没有额外的认证要求
   - 检查 CORS 设置

## 📊 监控和维护

### 监控脚本

创建监控脚本 `monitor.ps1`：

```powershell
# 监控所有服务状态
function Check-AllServices {
    Write-Host "=== 服务状态监控 ===" -ForegroundColor Cyan
    
    # 检查本地 MCP
    $mcpStatus = Test-NetConnection -ComputerName "localhost" -Port 3000 -InformationLevel Quiet
    Write-Host "本地 MCP 服务: $(if($mcpStatus){'✅ 运行中'}else{'❌ 停止'})"
    
    # 检查代理服务器
    $proxyStatus = Test-NetConnection -ComputerName "localhost" -Port 8080 -InformationLevel Quiet
    Write-Host "代理服务器: $(if($proxyStatus){'✅ 运行中'}else{'❌ 停止'})"
    
    # 检查隧道状态
    .\tunnel-solutions\tunnel-manager.ps1 -Method ngrok -Action status
}

# 每分钟检查一次
while ($true) {
    Check-AllServices
    Start-Sleep 60
}
```

### 自动重启脚本

创建自动重启脚本 `auto-restart.ps1`：

```powershell
# 自动重启失败的服务
function Restart-FailedServices {
    # 检查并重启本地 MCP
    $mcpStatus = Test-NetConnection -ComputerName "localhost" -Port 3000 -InformationLevel Quiet
    if (!$mcpStatus) {
        Write-Host "重启本地 MCP 服务..." -ForegroundColor Yellow
        Start-Process -FilePath "npm" -ArgumentList "start" -WorkingDirectory "xiaohongshu-mcp"
    }
    
    # 检查并重启代理服务器
    $proxyStatus = Test-NetConnection -ComputerName "localhost" -Port 8080 -InformationLevel Quiet
    if (!$proxyStatus) {
        Write-Host "重启代理服务器..." -ForegroundColor Yellow
        Start-Process -FilePath "node" -ArgumentList "mcp-proxy-server.js"
    }
}
```

## 🔒 安全考虑

### 安全最佳实践

1. **访问控制**
   ```javascript
   // 在代理服务器中添加 IP 白名单
   const allowedIPs = ['your-dify-server-ip'];
   
   app.use((req, res, next) => {
     const clientIP = req.ip;
     if (!allowedIPs.includes(clientIP)) {
       return res.status(403).json({ error: 'Access denied' });
     }
     next();
   });
   ```

2. **API 密钥认证**
   ```javascript
   // 添加 API 密钥验证
   const API_KEY = process.env.API_KEY || 'your-secret-key';
   
   app.use((req, res, next) => {
     const apiKey = req.headers['x-api-key'];
     if (apiKey !== API_KEY) {
       return res.status(401).json({ error: 'Invalid API key' });
     }
     next();
   });
   ```

3. **HTTPS 强制**
   ```javascript
   // 强制使用 HTTPS
   app.use((req, res, next) => {
     if (req.header('x-forwarded-proto') !== 'https') {
       res.redirect(`https://${req.header('host')}${req.url}`);
     } else {
       next();
     }
   });
   ```

## 📈 性能优化

### 优化建议

1. **连接池**
   ```javascript
   // 使用连接池优化性能
   const http = require('http');
   const agent = new http.Agent({
     keepAlive: true,
     maxSockets: 10
   });
   ```

2. **缓存策略**
   ```javascript
   // 添加响应缓存
   const cache = new Map();
   
   app.get('/mcp/check_login_status', (req, res) => {
     const cacheKey = 'login_status';
     const cached = cache.get(cacheKey);
     
     if (cached && Date.now() - cached.timestamp < 30000) {
       return res.json(cached.data);
     }
     
     // 获取新数据并缓存
     // ...
   });
   ```

3. **请求限制**
   ```javascript
   // 添加请求频率限制
   const rateLimit = require('express-rate-limit');
   
   const limiter = rateLimit({
     windowMs: 15 * 60 * 1000, // 15 分钟
     max: 100 // 限制每个 IP 100 次请求
   });
   
   app.use(limiter);
   ```

## 🎯 总结

通过本指南，您可以成功部署混合架构，实现：

1. ✅ 云端 Dify 调用本地 MCP 服务
2. ✅ 多种内网穿透方案选择
3. ✅ 完整的监控和维护机制
4. ✅ 安全和性能优化

选择最适合您需求的内网穿透方案，按照步骤部署，即可享受稳定可靠的混合架构服务。