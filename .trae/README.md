# Trae MCP 配置指南 - xiaohongshu-mcp

## 配置文件位置
Trae 的 MCP 配置文件已创建在：
```
e:\GitHub\xiaohongshu-mcp\.trae\mcp.json
```

## 配置内容
```json
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
```

## 服务状态
✅ xiaohongshu-mcp 服务正在运行
✅ 服务地址: http://localhost:18060/mcp
✅ 健康检查端口 18060 已开放

## 使用说明
1. 确保 xiaohongshu-mcp 服务已启动（端口 18060）
2. Trae 会自动加载 `.trae/mcp.json` 配置
3. 配置中包含重试机制和超时设置
4. 支持小红书内容发布、搜索等功能

## 验证配置
服务运行正常，MCP 端点已就绪。您可以在 Trae 中直接使用小红书 MCP 功能。