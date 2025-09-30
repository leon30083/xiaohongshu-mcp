# xiaohongshu-mcp 部署完成指南

## 🎯 Trae 中安装 MCP 工具

### 方法一：一键安装（推荐）
```powershell
# 在项目目录中运行
.\quick-install.ps1
```

### 方法二：完整安装脚本
```powershell
# 运行完整安装脚本（包含详细验证和便捷脚本）
.\install-trae-mcp.ps1
```

### 方法三：手动安装
```powershell
# 1. 创建配置目录
New-Item -ItemType Directory -Path ".\.trae" -Force

# 2. 创建 MCP 配置文件
@'
{
    "mcpServers": {
        "xiaohongshu-mcp": {
            "url": "http://localhost:18060/mcp",
            "description": "小红书内容发布服务 - MCP Streamable HTTP",
            "type": "http",
            "timeout": 30000,
            "retry": {
                "enabled": true,
                "maxAttempts": 3,
                "delay": 1000
            }
        }
    },
    "mcpInputs": {
        "xiaohongshu-mcp": {
            "cookiesPath": "./cookies.json",
            "browserPath": "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe",
            "headless": false,
            "timeout": 30
        }
    }
}
'@ | Out-File -FilePath ".\.trae\mcp.json" -Encoding UTF8

# 3. 启动服务
.\xiaohongshu-mcp.exe -headless=false
```

### 验证安装
```powershell
# 检查服务状态
Get-Process -Name "xiaohongshu-mcp"

# 测试 API
Invoke-RestMethod -Uri "http://localhost:18060/health"

# 测试 MCP 端点
Invoke-RestMethod -Uri "http://localhost:18060/mcp" -Method POST -ContentType "application/json" -Body '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
```

## 📁 文件结构

## 🎉 部署状态：成功完成

### ✅ 部署验证结果

- **环境检查**: Windows 10 Home 64-bit ✓
- **Go环境**: 依赖验证通过 ✓  
- **项目编译**: 生成 xiaohongshu-mcp.exe (19.9MB) ✓
- **服务启动**: MCP服务正在运行 (PID: 6692) ✓
- **端口监听**: TCP 18060 正常监听 ✓
- **客户端配置**: 配置文件已就绪 ✓

### 🔧 服务信息

- **服务地址**: http://localhost:18060
- **MCP端点**: http://localhost:18060/mcp
- **默认端口**: 18060
- **运行模式**: 无头浏览器模式
- **进程PID**: 6692

### 🛠️ 客户端配置

#### VSCode 配置
已配置: `.vscode/mcp.json`
```json
{
    "servers": {
        "xiaohongshu-mcp": {
            "url": "http://localhost:18060/mcp",
            "type": "http"
        }
    },
    "inputs": []
}
```

#### Cursor 配置  
已配置: `.cursor/mcp.json`
```json
{
    "mcpServers": {
        "xiaohongshu-mcp": {
            "url": "http://localhost:18060/mcp",
            "description": "小红书内容发布服务 - MCP Streamable HTTP"
        }
    }
}
```

### 📋 可用功能

1. **登录管理**: 小红书账号登录状态检查
2. **内容发布**: 图文和视频内容发布
3. **内容搜索**: 关键词搜索小红书内容
4. **推荐列表**: 获取首页推荐内容
5. **帖子详情**: 获取帖子完整信息和评论
6. **评论发布**: 自动发表评论
7. **用户主页**: 获取用户个人信息和笔记

### 🔍 服务验证

检查服务状态：
```powershell
# 检查进程
 tasklist | findstr xiaohongshu

# 检查端口
 netstat -an | findstr 18060

# 检查服务信息
 Get-Process -Name xiaohongshu-mcp
```

### ⚠️ 重要提示

1. **账号安全**: 同一账号不可在多个网页端同时登录
2. **发布限制**: 每日发帖量建议不超过50篇
3. **标题限制**: 标题不超过20个字
4. **网络要求**: 需要稳定的网络连接
5. **浏览器依赖**: 服务依赖无头浏览器进行自动化操作

### 🚨 服务管理

```powershell
# 停止服务
 Stop-Process -Name xiaohongshu-mcp

# 重新启动
 .\xiaohongshu-mcp.exe --port :18060 --headless true

# 查看日志 (在新终端中)
 # 服务日志会在启动终端中显示
```

### 📞 技术支持

- **项目地址**: https://github.com/xpzouying/xiaohongshu-mcp
- **问题反馈**: https://github.com/xpzouying/xiaohongshu-mcp/issues
- **文档**: 参见项目README.md文件

---

**✨ xiaohongshu-mcp 服务已成功部署并运行！**

现在你可以在VSCode或Cursor中配置MCP客户端连接，开始使用小红书自动化功能了。