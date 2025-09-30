# Trae 中安装 xiaohongshu-mcp

## 📋 安装前准备

### 系统要求
- Windows 10/11
- PowerShell 5.0+
- Chrome 浏览器
- Trae IDE

### 服务状态检查
确保 xiaohongshu-mcp 服务正在运行：
```powershell
# 检查服务进程
Get-Process -Name "xiaohongshu-mcp" -ErrorAction SilentlyContinue

# 检查服务端口
Test-NetConnection -ComputerName localhost -Port 18060
```

## 🚀 安装方法

### 方法一：一键安装（推荐）

在项目根目录运行：
```powershell
.\quick-install.ps1
```

这个脚本会自动：
- 创建 `.trae` 配置目录
- 生成正确的 `mcp.json` 配置文件
- 启动 xiaohongshu-mcp 服务
- 验证安装是否成功

### 方法二：完整安装脚本

如需更多控制选项：
```powershell
.\install-trae-mcp.ps1
```

### 方法三：手动安装

#### 1. 创建配置目录
```powershell
New-Item -ItemType Directory -Path ".\.trae" -Force
```

#### 2. 创建 MCP 配置文件
在 `.trae/mcp.json` 中添加以下内容：
```json
{
    "mcpServers": {
        "xiaohongshu-mcp": {
            "type": "sse",
            "url": "http://localhost:18060/mcp",
            "fromGalleryId": "modelcontextprotocol.servers_xiaohongshu-mcp"
        }
    }
}
```

#### 3. 启动服务
```powershell
.\xiaohongshu-mcp.exe -headless=false
```

## ✅ 验证安装

### 1. 检查配置文件
```powershell
Get-Content ".\.trae\mcp.json" | ConvertFrom-Json
```

### 2. 测试服务连接
```powershell
# 健康检查
Invoke-RestMethod -Uri "http://localhost:18060/health"

# MCP 端点检查
Invoke-RestMethod -Uri "http://localhost:18060/mcp"
```

### 3. 在 Trae 中验证
1. 打开 Trae IDE
2. 进入 MCP 设置界面
3. 确认 `xiaohongshu-mcp` 服务显示为已连接
4. 测试搜索功能：
   ```javascript
   // 在 Trae 中执行
   mcp.search_feeds({ keyword: "测试" })
   ```

## 🔧 配置说明

### MCP 配置参数
- **type**: `"sse"` - 使用 Server-Sent Events 协议
- **url**: `"http://localhost:18060/mcp"` - MCP 服务端点
- **fromGalleryId**: 服务标识符

### 服务配置
- **端口**: 18060
- **协议**: HTTP
- **超时**: 30秒

## 🛠️ 故障排除

### 常见问题

#### 1. 服务无法启动
```powershell
# 检查端口占用
netstat -ano | findstr :18060

# 强制结束占用进程
taskkill /PID <进程ID> /F
```

#### 2. MCP 连接失败
- 确认服务正在运行
- 检查防火墙设置
- 验证配置文件格式

#### 3. Trae 无法识别 MCP
- 重启 Trae IDE
- 检查 `.trae/mcp.json` 文件权限
- 确认配置文件格式正确

### 日志查看
```powershell
# 查看服务日志
.\xiaohongshu-mcp.exe -headless=false -debug=true
```

## 📚 下一步

安装完成后，请参考：
- [使用示例文档](./TRAE_USAGE_EXAMPLES.md)
- [API 文档](./docs/API.md)
- [主要功能说明](./README.md)

## 🆘 获取帮助

如遇问题，请：
1. 查看 [疑难杂症解答](https://github.com/xpzouying/xiaohongshu-mcp/issues/56)
2. 提交 [GitHub Issue](https://github.com/xpzouying/xiaohongshu-mcp/issues)
3. 参考项目文档