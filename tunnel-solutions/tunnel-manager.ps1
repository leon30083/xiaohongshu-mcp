# 统一隧道管理脚本
# 管理所有内网穿透方案

param(
    [ValidateSet("ngrok", "cloudflare", "frp", "tailscale")]
    [string]$Method = "",
    [ValidateSet("install", "setup", "start", "stop", "status", "help")]
    [string]$Action = "help",
    [hashtable]$Config = @{}
)

function Write-ColorText {
    param([string]$Text, [string]$Color = "White")
    $colors = @{
        "Red" = [ConsoleColor]::Red
        "Green" = [ConsoleColor]::Green
        "Yellow" = [ConsoleColor]::Yellow
        "Blue" = [ConsoleColor]::Blue
        "Cyan" = [ConsoleColor]::Cyan
        "Magenta" = [ConsoleColor]::Magenta
        "White" = [ConsoleColor]::White
    }
    Write-Host $Text -ForegroundColor $colors[$Color]
}

function Show-Help {
    Write-ColorText "=== 内网穿透统一管理工具 ===" "Cyan"
    Write-Host ""
    Write-ColorText "用法:" "Yellow"
    Write-Host "  .\tunnel-manager.ps1 -Method <方案> -Action <操作> [-Config @{参数=值}]"
    Write-Host ""
    Write-ColorText "支持的方案:" "Yellow"
    Write-Host "  ngrok      - 简单易用，适合初学者"
    Write-Host "  cloudflare - 免费稳定，适合生产环境"
    Write-Host "  frp        - 自建服务器，适合高级用户"
    Write-Host "  tailscale  - 利用现有网络，适合已有Tailscale用户"
    Write-Host ""
    Write-ColorText "支持的操作:" "Yellow"
    Write-Host "  install    - 安装工具"
    Write-Host "  setup      - 配置工具"
    Write-Host "  start      - 启动隧道"
    Write-Host "  stop       - 停止隧道"
    Write-Host "  status     - 查看状态"
    Write-Host "  help       - 显示帮助"
    Write-Host ""
    Write-ColorText "示例:" "Green"
    Write-Host "  # Ngrok快速开始"
    Write-Host "  .\tunnel-manager.ps1 -Method ngrok -Action install"
    Write-Host "  .\tunnel-manager.ps1 -Method ngrok -Action start"
    Write-Host ""
    Write-Host "  # Cloudflare设置"
    Write-Host "  .\tunnel-manager.ps1 -Method cloudflare -Action install"
    Write-Host "  .\tunnel-manager.ps1 -Method cloudflare -Action setup"
    Write-Host ""
    Write-Host "  # FRP配置"
    Write-Host "  .\tunnel-manager.ps1 -Method frp -Action setup -Config @{ServerIP='1.2.3.4'; Token='your-token'}"
    Write-Host ""
    Write-ColorText "方案对比:" "Blue"
    Write-Host ""
    Write-Host "┌─────────────┬──────────┬──────────┬──────────┬──────────┐" -ForegroundColor Gray
    Write-Host "│    方案     │   难度   │   费用   │   稳定性 │   推荐度 │" -ForegroundColor Gray
    Write-Host "├─────────────┼──────────┼──────────┼──────────┼──────────┤" -ForegroundColor Gray
    Write-Host "│   Ngrok     │    ⭐    │  免费/付费│    ⭐⭐⭐  │    ⭐⭐⭐⭐ │" -ForegroundColor White
    Write-Host "│ Cloudflare  │   ⭐⭐   │   免费   │   ⭐⭐⭐⭐⭐ │   ⭐⭐⭐⭐⭐ │" -ForegroundColor White
    Write-Host "│     FRP     │  ⭐⭐⭐⭐  │ 需要服务器│   ⭐⭐⭐⭐⭐ │    ⭐⭐⭐  │" -ForegroundColor White
    Write-Host "│  Tailscale  │   ⭐⭐⭐  │   免费   │   ⭐⭐⭐⭐⭐ │    ⭐⭐⭐⭐ │" -ForegroundColor White
    Write-Host "└─────────────┴──────────┴──────────┴──────────┴──────────┘" -ForegroundColor Gray
    Write-Host ""
    Write-ColorText "推荐选择:" "Green"
    Write-Host "  🥇 初学者: Ngrok"
    Write-Host "  🥇 生产环境: Cloudflare Tunnel"
    Write-Host "  🥇 已有Tailscale: Tailscale Funnel"
    Write-Host "  🥇 高级用户: FRP"
}

function Get-ScriptPath {
    param([string]$Method)
    
    $scriptDir = Split-Path -Parent $MyInvocation.ScriptName
    $scripts = @{
        "ngrok" = "$scriptDir\ngrok-setup.ps1"
        "cloudflare" = "$scriptDir\cloudflare-tunnel.ps1"
        "frp" = "$scriptDir\frp-setup.ps1"
        "tailscale" = "$scriptDir\tailscale-funnel.ps1"
    }
    
    return $scripts[$Method]
}

function Invoke-TunnelScript {
    param(
        [string]$Method,
        [string]$Action,
        [hashtable]$Config
    )
    
    $scriptPath = Get-ScriptPath -Method $Method
    
    if (!(Test-Path $scriptPath)) {
        Write-ColorText "❌ 找不到脚本: $scriptPath" "Red"
        return
    }
    
    Write-ColorText "🚀 执行 $Method $Action..." "Cyan"
    
    # 构建参数
    $params = @()
    
    switch ($Action) {
        "install" { $params += "-Install" }
        "setup" { $params += "-Setup" }
        "start" { $params += "-Start" }
        "stop" { $params += "-Stop" }
        "status" { $params += "-Status" }
        "help" { $params += "-Help" }
    }
    
    # 添加配置参数
    foreach ($key in $Config.Keys) {
        $params += "-$key"
        $params += $Config[$key]
    }
    
    # 执行脚本
    try {
        & $scriptPath @params
    } catch {
        Write-ColorText "❌ 执行失败: $($_.Exception.Message)" "Red"
    }
}

function Show-QuickStart {
    Write-ColorText "=== 快速开始指南 ===" "Cyan"
    Write-Host ""
    
    Write-ColorText "🎯 推荐方案选择:" "Yellow"
    Write-Host ""
    
    Write-ColorText "1. 新手推荐 - Ngrok" "Green"
    Write-Host "   优点: 简单易用，一键启动"
    Write-Host "   缺点: 免费版有限制"
    Write-Host "   命令: .\tunnel-manager.ps1 -Method ngrok -Action install"
    Write-Host "         .\tunnel-manager.ps1 -Method ngrok -Action start"
    Write-Host ""
    
    Write-ColorText "2. 生产推荐 - Cloudflare Tunnel" "Green"
    Write-Host "   优点: 免费、稳定、无限制"
    Write-Host "   缺点: 需要Cloudflare账号"
    Write-Host "   命令: .\tunnel-manager.ps1 -Method cloudflare -Action install"
    Write-Host "         .\tunnel-manager.ps1 -Method cloudflare -Action setup"
    Write-Host ""
    
    Write-ColorText "3. 已有Tailscale - Tailscale Funnel" "Green"
    Write-Host "   优点: 利用现有基础设施"
    Write-Host "   缺点: 需要Tailscale账号"
    Write-Host "   命令: .\tunnel-manager.ps1 -Method tailscale -Action setup"
    Write-Host "         .\tunnel-manager.ps1 -Method tailscale -Action start"
    Write-Host ""
    
    Write-ColorText "4. 高级用户 - FRP" "Green"
    Write-Host "   优点: 完全控制，高性能"
    Write-Host "   缺点: 需要自己的服务器"
    Write-Host "   命令: .\tunnel-manager.ps1 -Method frp -Action install"
    Write-Host "         .\tunnel-manager.ps1 -Method frp -Action setup -Config @{ServerIP='your-server'; Token='your-token'}"
    Write-Host ""
    
    Write-ColorText "💡 建议:" "Blue"
    Write-Host "  - 测试阶段: 使用 Ngrok"
    Write-Host "  - 生产环境: 使用 Cloudflare Tunnel"
    Write-Host "  - 企业用户: 使用 FRP 或 Tailscale"
}

function Check-Prerequisites {
    Write-ColorText "🔍 检查前置条件..." "Cyan"
    
    # 检查MCP代理服务器
    $mcpProxy = Get-NetTCPConnection -LocalPort 8080 -ErrorAction SilentlyContinue
    if ($mcpProxy) {
        Write-ColorText "✅ MCP代理服务器正在运行 (端口 8080)" "Green"
    } else {
        Write-ColorText "⚠️  MCP代理服务器未运行" "Yellow"
        Write-ColorText "请先启动: npm start" "Yellow"
    }
    
    # 检查网络连接
    try {
        $ping = Test-NetConnection -ComputerName "8.8.8.8" -Port 53 -InformationLevel Quiet
        if ($ping) {
            Write-ColorText "✅ 网络连接正常" "Green"
        } else {
            Write-ColorText "❌ 网络连接异常" "Red"
        }
    } catch {
        Write-ColorText "❌ 网络检查失败" "Red"
    }
    
    Write-Host ""
}

# 主执行逻辑
if ($Action -eq "help" -and !$Method) {
    Show-Help
    Write-Host ""
    Show-QuickStart
    exit 0
}

if (!$Method) {
    Write-ColorText "❌ 请指定内网穿透方案" "Red"
    Write-ColorText "用法: .\tunnel-manager.ps1 -Method <方案> -Action <操作>" "Yellow"
    Write-ColorText "运行 .\tunnel-manager.ps1 -Action help 查看详细帮助" "Blue"
    exit 1
}

# 检查前置条件
if ($Action -in @("start", "status")) {
    Check-Prerequisites
}

# 执行对应的脚本
Invoke-TunnelScript -Method $Method -Action $Action -Config $Config