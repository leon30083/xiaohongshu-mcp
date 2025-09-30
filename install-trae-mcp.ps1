# xiaohongshu-mcp Trae 自动安装脚本
# 作者: AI Assistant
# 版本: 1.0
# 描述: 自动配置 xiaohongshu-mcp 在 Trae 中的 MCP 环境

param(
    [string]$ProjectPath = (Get-Location).Path,
    [int]$ServicePort = 18060,
    [bool]$AutoStart = $true,
    [bool]$Headless = $false
)

# 设置控制台编码
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "🚀 xiaohongshu-mcp Trae 安装脚本" -ForegroundColor Cyan
Write-Host "=" * 50 -ForegroundColor Gray
Write-Host "项目路径: $ProjectPath" -ForegroundColor White
Write-Host "服务端口: $ServicePort" -ForegroundColor White
Write-Host "自动启动: $AutoStart" -ForegroundColor White
Write-Host "无头模式: $Headless" -ForegroundColor White
Write-Host "=" * 50 -ForegroundColor Gray

# 检查项目目录
if (!(Test-Path "$ProjectPath\xiaohongshu-mcp.exe")) {
    Write-Host "❌ 错误: 在 $ProjectPath 中未找到 xiaohongshu-mcp.exe" -ForegroundColor Red
    Write-Host "请确保在正确的项目目录中运行此脚本" -ForegroundColor Yellow
    exit 1
}

# 1. 创建 .trae 配置目录
$TraeConfigDir = "$ProjectPath\.trae"
Write-Host "`n📁 创建 Trae 配置目录..." -ForegroundColor Yellow

if (!(Test-Path $TraeConfigDir)) {
    try {
        New-Item -ItemType Directory -Path $TraeConfigDir -Force | Out-Null
        Write-Host "✅ 创建目录: $TraeConfigDir" -ForegroundColor Green
    } catch {
        Write-Host "❌ 创建目录失败: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "✅ 目录已存在: $TraeConfigDir" -ForegroundColor Green
}

# 2. 生成 MCP 配置
Write-Host "`n⚙️  生成 MCP 配置..." -ForegroundColor Yellow

$ServiceUrl = "http://localhost:$ServicePort"
$McpConfigFile = "$TraeConfigDir\mcp.json"

# 检测 Chrome 浏览器路径
$ChromePaths = @(
    "C:\Program Files\Google\Chrome\Application\chrome.exe",
    "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
)

$ChromePath = $ChromePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
if (!$ChromePath) {
    $ChromePath = "chrome.exe"  # 使用系统 PATH
    Write-Host "⚠️  未找到 Chrome 安装路径，使用默认值" -ForegroundColor Yellow
} else {
    Write-Host "✅ 检测到 Chrome: $ChromePath" -ForegroundColor Green
}

# 创建配置对象
$McpConfig = @{
    mcpServers = @{
        "xiaohongshu-mcp" = @{
            type = "sse"
            url = "$ServiceUrl/mcp"
            fromGalleryId = "modelcontextprotocol.servers_xiaohongshu-mcp"
        }
    }
}

# 保存配置文件
try {
    $McpConfig | ConvertTo-Json -Depth 10 | Out-File -FilePath $McpConfigFile -Encoding UTF8
    Write-Host "✅ 配置文件已创建: $McpConfigFile" -ForegroundColor Green
} catch {
    Write-Host "❌ 配置文件创建失败: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# 3. 检查并启动服务
Write-Host "`n🔍 检查服务状态..." -ForegroundColor Yellow

# 检查现有进程
$ExistingProcess = Get-Process -Name "xiaohongshu-mcp" -ErrorAction SilentlyContinue
if ($ExistingProcess) {
    Write-Host "✅ 服务已运行 (PID: $($ExistingProcess.Id))" -ForegroundColor Green
    
    # 检查端口
    $PortCheck = netstat -an | Select-String ":$ServicePort.*LISTENING"
    if ($PortCheck) {
        Write-Host "✅ 端口 $ServicePort 正在监听" -ForegroundColor Green
    } else {
        Write-Host "⚠️  端口 $ServicePort 未监听，可能需要重启服务" -ForegroundColor Yellow
    }
} elseif ($AutoStart) {
    Write-Host "🚀 启动 xiaohongshu-mcp 服务..." -ForegroundColor Yellow
    
    try {
        Set-Location $ProjectPath
        $Arguments = if ($Headless) { "-headless=true" } else { "-headless=false" }
        
        Start-Process -FilePath ".\xiaohongshu-mcp.exe" -ArgumentList $Arguments -WindowStyle Hidden
        Start-Sleep -Seconds 3
        
        $NewProcess = Get-Process -Name "xiaohongshu-mcp" -ErrorAction SilentlyContinue
        if ($NewProcess) {
            Write-Host "✅ 服务启动成功 (PID: $($NewProcess.Id))" -ForegroundColor Green
        } else {
            Write-Host "❌ 服务启动失败" -ForegroundColor Red
        }
    } catch {
        Write-Host "❌ 启动服务时出错: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "⚠️  服务未运行，请手动启动" -ForegroundColor Yellow
}

# 4. 验证安装
Write-Host "`n🧪 验证安装..." -ForegroundColor Yellow

# 等待服务完全启动
Start-Sleep -Seconds 2

# 测试健康检查
try {
    $HealthResponse = Invoke-RestMethod -Uri "$ServiceUrl/health" -Method GET -TimeoutSec 10
    if ($HealthResponse.success) {
        Write-Host "✅ 健康检查通过" -ForegroundColor Green
        Write-Host "   服务状态: $($HealthResponse.data.status)" -ForegroundColor Cyan
        Write-Host "   账户: $($HealthResponse.data.account)" -ForegroundColor Cyan
    } else {
        Write-Host "⚠️  健康检查失败" -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠️  无法连接到服务: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 测试 MCP 端点
try {
    $McpTestBody = @{
        jsonrpc = "2.0"
        id = 1
        method = "tools/list"
    } | ConvertTo-Json

    $McpResponse = Invoke-RestMethod -Uri "$ServiceUrl/mcp" -Method POST -Body $McpTestBody -ContentType "application/json" -TimeoutSec 10
    if ($McpResponse.result) {
        $ToolCount = $McpResponse.result.tools.Count
        Write-Host "✅ MCP 端点测试通过，发现 $ToolCount 个工具" -ForegroundColor Green
    }
} catch {
    Write-Host "⚠️  MCP 端点测试失败: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 5. 创建便捷脚本
Write-Host "`n📝 创建便捷脚本..." -ForegroundColor Yellow

# 启动脚本
$StartScript = @"
# xiaohongshu-mcp 启动脚本
# 自动生成于 $(Get-Date)

Set-Location "$ProjectPath"

# 检查是否已运行
`$existing = Get-Process -Name "xiaohongshu-mcp" -ErrorAction SilentlyContinue
if (`$existing) {
    Write-Host "服务已在运行 (PID: `$(`$existing.Id))" -ForegroundColor Yellow
    exit 0
}

# 启动服务
Write-Host "启动 xiaohongshu-mcp 服务..." -ForegroundColor Green
Start-Process -FilePath ".\xiaohongshu-mcp.exe" -ArgumentList "$Arguments"

# 等待启动
Start-Sleep -Seconds 3

# 验证启动
`$process = Get-Process -Name "xiaohongshu-mcp" -ErrorAction SilentlyContinue
if (`$process) {
    Write-Host "✅ 服务启动成功 (PID: `$(`$process.Id))" -ForegroundColor Green
} else {
    Write-Host "❌ 服务启动失败" -ForegroundColor Red
}
"@

$StartScript | Out-File -FilePath "$ProjectPath\start-mcp.ps1" -Encoding UTF8
Write-Host "✅ 启动脚本: start-mcp.ps1" -ForegroundColor Green

# 停止脚本
$StopScript = @"
# xiaohongshu-mcp 停止脚本
# 自动生成于 $(Get-Date)

Write-Host "停止 xiaohongshu-mcp 服务..." -ForegroundColor Yellow

`$processes = Get-Process -Name "xiaohongshu-mcp" -ErrorAction SilentlyContinue
if (`$processes) {
    `$processes | ForEach-Object {
        Write-Host "停止进程 PID: `$(`$_.Id)" -ForegroundColor Yellow
        Stop-Process -Id `$_.Id -Force
    }
    Write-Host "✅ 服务已停止" -ForegroundColor Green
} else {
    Write-Host "⚠️  未找到运行中的服务" -ForegroundColor Yellow
}
"@

$StopScript | Out-File -FilePath "$ProjectPath\stop-mcp.ps1" -Encoding UTF8
Write-Host "✅ 停止脚本: stop-mcp.ps1" -ForegroundColor Green

# 6. 安装总结
Write-Host "`n" + "=" * 50 -ForegroundColor Gray
Write-Host "🎉 安装完成！" -ForegroundColor Green
Write-Host "=" * 50 -ForegroundColor Gray

Write-Host "`n📋 安装信息:" -ForegroundColor Cyan
Write-Host "   配置文件: $McpConfigFile" -ForegroundColor White
Write-Host "   服务地址: $ServiceUrl/mcp" -ForegroundColor White
Write-Host "   健康检查: $ServiceUrl/health" -ForegroundColor White

Write-Host "`n🛠️  便捷命令:" -ForegroundColor Cyan
Write-Host "   启动服务: .\start-mcp.ps1" -ForegroundColor White
Write-Host "   停止服务: .\stop-mcp.ps1" -ForegroundColor White

Write-Host "`n📖 使用说明:" -ForegroundColor Cyan
Write-Host "   1. Trae 会自动加载 .trae\mcp.json 配置" -ForegroundColor White
Write-Host "   2. 确保 xiaohongshu-mcp 服务保持运行" -ForegroundColor White
Write-Host "   3. 在 Trae 中可直接调用小红书 MCP 工具" -ForegroundColor White

Write-Host "`n🔧 故障排除:" -ForegroundColor Cyan
Write-Host "   检查服务: Get-Process -Name 'xiaohongshu-mcp'" -ForegroundColor White
Write-Host "   检查端口: netstat -an | Select-String ':$ServicePort'" -ForegroundColor White
Write-Host "   测试API: Invoke-RestMethod -Uri '$ServiceUrl/health'" -ForegroundColor White

Write-Host "`n✨ 安装脚本执行完成！" -ForegroundColor Green