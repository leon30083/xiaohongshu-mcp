# 🚀 小红书MCP工具启动指南

## 🎯 一键启动脚本 (推荐)

我们提供了多个平台的一键启动脚本，让MCP服务器的启动变得更加便捷：

### **Windows PowerShell (功能最全)** ✅
```powershell
# 基本启动
.\start-mcp.ps1

# 编译后启动
.\start-mcp.ps1 -Build

# 检查服务状态
.\start-mcp.ps1 -Check

# 重启服务
.\start-mcp.ps1 -Restart

# 停止服务
.\start-mcp.ps1 -Stop

# 显示帮助
.\start-mcp.ps1 -Help
```

**脚本特性：**
- ✅ 自动环境检查（Go版本、项目依赖）
- ✅ 智能进程管理（启动、停止、重启）
- ✅ 实时状态监控和健康检查
- ✅ 彩色输出和详细日志
- ✅ 错误处理和重试机制

### **Windows 批处理 (简化版)**
```cmd
# 双击运行或命令行执行
start-mcp.bat
```

### **Linux/macOS**
```bash
# 添加执行权限（首次使用）
chmod +x start-mcp.sh

# 基本启动
./start-mcp.sh

# 编译后启动
./start-mcp.sh --build

# 检查状态
./start-mcp.sh --check

# 重启服务
./start-mcp.sh --restart

# 停止服务
./start-mcp.sh --stop
```

## 📋 手动启动步骤

### 1. **启动MCP服务器**

在项目根目录执行：
```powershell
# 方法1：直接运行Go程序
go run . server

# 方法2：编译后运行
go build -o xiaohongshu-mcp.exe
./xiaohongshu-mcp.exe server
```

### 2. **验证服务状态**

访问健康检查端点：
```powershell
curl http://localhost:18060/health
```

预期返回：`{"status":"ok"}`

### 3. **Trae自动连接**

当MCP服务器启动后，Trae会自动：
- 读取 `.trae\mcp.json` 配置
- 连接到 `http://localhost:18060/mcp`
- 加载9个小红书MCP工具

## 🔧 配置说明

### **项目级MCP配置** (`.trae\mcp.json`)
```json
{
    "mcpServers": {
        "xiaohongshu-mcp": {
            "type": "sse",                    // 服务器事件流类型
            "url": "http://localhost:18060/mcp", // 本地MCP端点
            "timeout": 30000                  // 30秒超时
        }
    }
}
```

### **可用的MCP工具**
1. `mcp_xiaohongshu-mcp_check_login_status` - 检查登录状态
2. `mcp_xiaohongshu-mcp_get_login_qrcode` - 获取登录二维码
3. `mcp_xiaohongshu-mcp_search_feeds` - 搜索内容
4. `mcp_xiaohongshu-mcp_get_feed_detail` - 获取内容详情
5. `mcp_xiaohongshu-mcp_user_profile` - 获取用户资料
6. `mcp_xiaohongshu-mcp_list_feeds` - 列出用户内容
7. `mcp_xiaohongshu-mcp_publish_content` - 发布图文内容
8. `mcp_xiaohongshu-mcp_publish_with_video` - 发布视频内容
9. `mcp_xiaohongshu-mcp_post_comment_to_feed` - 发表评论

## 🎯 工作原理

### **MCP连接流程**
```
Trae IDE → 读取.trae/mcp.json → 连接localhost:18060/mcp → 加载MCP工具
```

### **项目级 vs 全局配置**
- **项目级配置**：仅在当前项目生效，优先级更高
- **全局配置**：所有项目通用，但会被项目级配置覆盖

## 🚨 常见问题

### **Q: 为什么全局MCP中没有设置，但能调用？**
**A:** 因为Trae使用了**项目级MCP配置** (`.trae\mcp.json`)，它的优先级高于全局配置。

### **Q: 如何确认MCP工具已加载？**
**A:** 查看服务器日志中的 `Registered 9 MCP tools` 消息。

### **Q: 服务器启动失败怎么办？**
**A:** 检查：
1. 端口18060是否被占用
2. Go环境是否正确安装
3. 项目依赖是否完整 (`go mod tidy`)

## 💡 最佳实践

1. **开发时**：使用 `go run . server` 便于调试
2. **生产时**：编译后运行，性能更好
3. **团队协作**：确保 `.trae\mcp.json` 已提交到版本控制
4. **端口管理**：避免与其他服务冲突

## 🔄 重启流程

如果需要重启MCP服务：
1. 在终端按 `Ctrl+C` 停止服务
2. 重新运行 `go run . server`
3. Trae会自动重新连接