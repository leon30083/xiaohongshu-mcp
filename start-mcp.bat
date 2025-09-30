@echo off
REM 🚀 小红书MCP服务器简易启动脚本
REM 适用于Windows系统的快速启动

echo.
echo 🚀 启动小红书MCP服务器...
echo ================================

REM 检查Go环境
go version >nul 2>&1
if errorlevel 1 (
    echo ❌ 错误: 未找到Go环境，请先安装Go
    pause
    exit /b 1
)

echo ✅ Go环境检查通过

REM 检查端口占用
netstat -an | find "18060" >nul
if not errorlevel 1 (
    echo ⚠️  警告: 端口18060已被占用
    echo 请手动停止现有服务或使用 start-mcp.ps1 -Restart
)

REM 启动服务
echo 🎯 启动MCP服务器...
echo 提示: 按Ctrl+C可停止服务
echo.

go run . server

echo.
echo 服务已停止
pause