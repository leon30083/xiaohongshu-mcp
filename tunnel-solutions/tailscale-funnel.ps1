# Tailscale Funnel设置脚本
# 利用现有Tailscale网络，优雅的解决方案

param(
    [switch]$Setup,
    [switch]$Start,
    [switch]$Stop,
    [switch]$Status,
    [switch]$Help,
    [int]$Port = 8080,
    [string]$Subdomain = "xiaohongshu-mcp"
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
    Write-ColorText "=== Tailscale Funnel设置工具 ===" "Cyan"
    Write-Host ""
    Write-ColorText "用法:" "Yellow"
    Write-Host "  .\tailscale-funnel.ps1 [选项]"
    Write-Host ""
    Write-ColorText "选项:" "Yellow"
    Write-Host "  -Setup                配置Tailscale Funnel"
    Write-Host "  -Start                启动Funnel"
    Write-Host "  -Stop                 停止Funnel"
    Write-Host "  -Status               查看Funnel状态"
    Write-Host "  -Port <port>          本地服务端口（默认: 8080）"
    Write-Host "  -Subdomain <name>     子域名（默认: xiaohongshu-mcp）"
    Write-Host "  -Help                 显示帮助"
    Write-Host ""
    Write-ColorText "完整设置流程:" "Green"
    Write-Host "  1. .\tailscale-funnel.ps1 -Setup"
    Write-Host "  2. .\tailscale-funnel.ps1 -Start"
    Write-Host ""
    Write-ColorText "前置条件:" "Yellow"
    Write-Host "  1. 已安装并登录Tailscale"
    Write-Host "  2. Tailscale账号支持Funnel功能"
    Write-Host "  3. 设备已连接到Tailscale网络"
    Write-Host ""
    Write-ColorText "优势:" "Blue"
    Write-Host "  ✅ 利用现有Tailscale基础设施"
    Write-Host "  ✅ 自动HTTPS证书"
    Write-Host "  ✅ 高安全性"
    Write-Host "  ✅ 简单配置"
}

function Check-Tailscale {
    Write-ColorText "🔍 检查Tailscale状态..." "Cyan"
    
    # 检查Tailscale是否安装
    if (!(Get-Command tailscale -ErrorAction SilentlyContinue)) {
        Write-ColorText "❌ Tailscale未安装" "Red"
        Write-ColorText "请先安装Tailscale: https://tailscale.com/download" "Yellow"
        return $false
    }
    
    # 检查Tailscale状态
    try {
        $status = & tailscale status --json | ConvertFrom-Json
        
        if ($status.BackendState -eq "Running") {
            Write-ColorText "✅ Tailscale正在运行" "Green"
            Write-Host "  设备名称: $($status.Self.HostName)" -ForegroundColor White
            Write-Host "  Tailscale IP: $($status.Self.TailscaleIPs[0])" -ForegroundColor White
            return $true
        } else {
            Write-ColorText "❌ Tailscale未连接" "Red"
            Write-ColorText "请先连接Tailscale: tailscale up" "Yellow"
            return $false
        }
    } catch {
        Write-ColorText "❌ 无法获取Tailscale状态: $($_.Exception.Message)" "Red"
        return $false
    }
}

function Setup-TailscaleFunnel {
    param([int]$Port, [string]$Subdomain)
    
    Write-ColorText "⚙️  配置Tailscale Funnel..." "Cyan"
    
    if (!(Check-Tailscale)) {
        return
    }
    
    try {
        # 检查Funnel功能是否可用
        Write-ColorText "🔍 检查Funnel功能..." "Yellow"
        $funnelStatus = & tailscale funnel status 2>&1
        
        # 启用HTTPS
        Write-ColorText "🔒 启用HTTPS..." "Yellow"
        & tailscale cert --domain="$Subdomain"
        
        Write-ColorText "✅ Tailscale Funnel配置完成" "Green"
        Write-ColorText "📋 配置信息:" "Blue"
        Write-Host "  本地端口: $Port" -ForegroundColor White
        Write-Host "  子域名: $Subdomain" -ForegroundColor White
        
    } catch {
        Write-ColorText "❌ 配置失败: $($_.Exception.Message)" "Red"
        Write-ColorText "💡 提示: 确保您的Tailscale账号支持Funnel功能" "Yellow"
    }
}

function Start-TailscaleFunnel {
    param([int]$Port, [string]$Subdomain)
    
    Write-ColorText "🚀 启动Tailscale Funnel..." "Cyan"
    
    if (!(Check-Tailscale)) {
        return
    }
    
    # 检查本地服务
    $portCheck = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue
    if (!$portCheck) {
        Write-ColorText "⚠️  警告: 端口 $Port 没有服务在运行" "Yellow"
        Write-ColorText "请先启动MCP代理服务器: npm start" "Yellow"
    }
    
    try {
        # 获取设备信息
        $status = & tailscale status --json | ConvertFrom-Json
        $deviceName = $status.Self.HostName
        $domain = "$deviceName.tailscale.net"
        
        Write-ColorText "🌐 启动Funnel..." "Yellow"
        Write-ColorText "🔗 公网访问地址: https://$domain" "Cyan"
        Write-Host "按 Ctrl+C 停止Funnel" -ForegroundColor Gray
        Write-Host ""
        
        # 启动Funnel
        & tailscale funnel $Port
        
    } catch {
        Write-ColorText "❌ Funnel启动失败: $($_.Exception.Message)" "Red"
        
        # 提供故障排除建议
        Write-ColorText "🔧 故障排除建议:" "Yellow"
        Write-Host "  1. 检查Tailscale账号是否支持Funnel功能"
        Write-Host "  2. 确保设备已正确连接到Tailscale网络"
        Write-Host "  3. 检查本地端口 $Port 是否有服务在运行"
        Write-Host "  4. 尝试重新登录Tailscale: tailscale logout && tailscale up"
    }
}

function Get-TailscaleFunnelStatus {
    Write-ColorText "📊 检查Tailscale Funnel状态..." "Cyan"
    
    if (!(Check-Tailscale)) {
        return
    }
    
    try {
        # 检查Funnel状态
        $funnelStatus = & tailscale funnel status 2>&1
        
        if ($funnelStatus -match "no funnel configured") {
            Write-ColorText "❌ 没有配置Funnel" "Red"
        } elseif ($funnelStatus -match "Funnel on") {
            Write-ColorText "✅ Funnel正在运行" "Green"
            Write-Host $funnelStatus -ForegroundColor White
        } else {
            Write-ColorText "📋 Funnel状态:" "Blue"
            Write-Host $funnelStatus -ForegroundColor White
        }
        
        # 检查本地端口
        $portCheck = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue
        if ($portCheck) {
            Write-ColorText "✅ 本地端口 $Port 正在监听" "Green"
        } else {
            Write-ColorText "❌ 本地端口 $Port 未监听" "Red"
        }
        
        # 显示访问地址
        $status = & tailscale status --json | ConvertFrom-Json
        $deviceName = $status.Self.HostName
        $domain = "$deviceName.tailscale.net"
        Write-ColorText "🔗 访问地址: https://$domain" "Cyan"
        
    } catch {
        Write-ColorText "❌ 无法获取Funnel状态: $($_.Exception.Message)" "Red"
    }
}

function Stop-TailscaleFunnel {
    Write-ColorText "🛑 停止Tailscale Funnel..." "Cyan"
    
    try {
        & tailscale funnel reset
        Write-ColorText "✅ Tailscale Funnel已停止" "Green"
    } catch {
        Write-ColorText "❌ 停止Funnel失败: $($_.Exception.Message)" "Red"
    }
}

# 主执行逻辑
if ($Help) {
    Show-Help
    exit 0
}

if ($Setup) {
    Setup-TailscaleFunnel -Port $Port -Subdomain $Subdomain
    exit 0
}

if ($Start) {
    Start-TailscaleFunnel -Port $Port -Subdomain $Subdomain
    exit 0
}

if ($Stop) {
    Stop-TailscaleFunnel
    exit 0
}

if ($Status) {
    Get-TailscaleFunnelStatus
    exit 0
}

# 默认显示帮助
Show-Help