// MCP代理服务器 - 连接云端Dify和本地MCP
const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 8080;
const LOCAL_MCP_URL = process.env.LOCAL_MCP_URL || 'http://localhost:18060';

// 启用CORS
app.use(cors());

// 健康检查
app.get('/health', (req, res) => {
    res.json({ 
        status: 'healthy', 
        proxy_target: LOCAL_MCP_URL,
        timestamp: new Date().toISOString()
    });
});

// 代理所有MCP请求到本地
app.use('/mcp', createProxyMiddleware({
    target: 'http://127.0.0.1:18060',  // 强制使用 IPv4
    changeOrigin: true,
    pathRewrite: {
        '^/mcp': '/mcp'
    },
    timeout: 30000,  // 30秒超时
    proxyTimeout: 30000,
    onError: (err, req, res) => {
        console.error('代理错误:', err.message);
        res.status(500).json({
            error: '本地MCP服务不可用',
            message: err.message,
            target: 'http://127.0.0.1:18060'
        });
    },
    onProxyReq: (proxyReq, req, res) => {
        console.log(`代理请求: ${req.method} ${req.url} -> http://127.0.0.1:18060${req.url}`);
    }
}));

// 启动服务器
app.listen(PORT, () => {
    console.log(`🚀 MCP代理服务器启动成功`);
    console.log(`📡 监听端口: ${PORT}`);
    console.log(`🎯 代理目标: ${LOCAL_MCP_URL}`);
    console.log(`🌐 访问地址: http://localhost:${PORT}`);
    console.log(`💚 健康检查: http://localhost:${PORT}/health`);
});

module.exports = app;