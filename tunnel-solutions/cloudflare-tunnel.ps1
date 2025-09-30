# Cloudflare Tunnel设置脚本
# 适用于生产环境，免费且稳定

param(
    [switch]$Install,
    [switch]$Login,
    [switch]$Create,
    [switch]$Start,
    [switch]$Stop,
    [switch]$Status,
    [switch]$Help,
    [string]$TunnelName = "xiaohongshu-mcp",
    [string]$Domain = "",
    [int]$Port = 8080
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
    Write-ColorText "=== Cloudflare Tunnel设置工具 ===" "Cyan"
    Write-Host ""
    Write-ColorText "用法:" "Yellow"
    Write-Host "  .\cloudflare-tunnel.ps1 [选项]"
    Write-Host ""
    Write-ColorText "选项:" "Yellow"
    Write-Host "  -Install              安装cloudflared"
    Write-Host "  -Login                登录Cloudflare账号"
    Write-Host "  -Create               创建隧道"
    Write-Host "  -Start                启动隧道"
    Write-Host "  -Stop                 停止隧道"
    Write-Host "  -Status               查看隧道状态"
    Write-Host "  -TunnelName <name>    隧道名称（默认: xiaohongshu-mcp）"
    Write-Host "  -Domain <domain>      自定义域名（可选）"
    Write-Host "  -Port <port>          本地端口（默认: 8080）"
    Write-Host "  -Help                 显示帮助"
    Write-Host ""
    Write-ColorText "完整设置流程:" "Green"
    Write-Host "  1. .\cloudflare-tunnel.ps1 -Install"
    Write-Host "  2. .\cloudflare-tunnel.ps1 -Login"
    Write-Host "  3. .\cloudflare-tunnel.ps1 -Create"
    Write-Host "  4. .\cloudflare-tunnel.ps1 -Start"
    Write-Host ""
    Write-ColorText "前置条件:" "Yellow"
    Write-Host "  1. 拥有Cloudflare账号（免费）"
    Write-Host "  2. 域名已添加到Cloudflare（可选，可用免费域名）"
}

function Install-Cloudflared {
    Write-ColorText "🔽 安装Cloudflared..." "Cyan"
    
    # 检查是否已安装
    if (Get-Command cloudflared -ErrorAction SilentlyContinue) {
        Write-ColorText "✅ Cloudflared已安装" "Green"
        & cloudflared version
        return
    }
    
    Write-ColorText "📥 下载Cloudflared..." "Yellow"
    $downloadUrl = "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe"
    $installPath = "$env:LOCALAPPDATA\cloudflared"
    $exePath = "$installPath\cloudflared.exe"
    
    # 创建目录
    if (!(Test-Path $installPath)) {
        New-Item -ItemType Directory -Path $installPath -Force | Out-Null
    }
    
    # 下载
    try {
        Invoke-WebRequest -Uri $downloadUrl -OutFile $exePath
        
        # 添加到PATH
        $currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
        if ($currentPath -notlike "*$installPath*") {
            [Environment]::SetEnvironmentVariable("PATH", "$currentPath;$installPath", "User")
            $env:PATH += ";$installPath"
        }
        
        Write-ColorText "✅ Cloudflared安装完成" "Green"
        & cloudflared version
    } catch {
        Write-ColorText "❌ 下载失败: $($_.Exception.Message)" "Red"
    }
}

function Login-Cloudflare {
    Write-ColorText "🔑 登录Cloudflare账号..." "Cyan"
    Write-ColorText "浏览器将打开，请完成登录授权" "Yellow"
    
    try {
        & cloudflared tunnel login
        Write-ColorText "✅ 登录成功" "Green"
    } catch {
        Write-ColorText "❌ 登录失败: $($_.Exception.Message)" "Red"
    }
}

function Create-Tunnel {
    param([string]$Name)
    
    Write-ColorText "🚇 创建隧道: $Name" "Cyan"
    
    try {
        # 创建隧道
        $output = & cloudflared tunnel create $Name 2>&1
        Write-ColorText "✅ 隧道创建成功" "Green"
        
        # 获取隧道ID
        $tunnelList = & cloudflared tunnel list
        Write-ColorText "📋 当前隧道列表:" "Blue"
        Write-Host $tunnelList
        
        # 创建配置文件
        Create-TunnelConfig -TunnelName $Name
        
    } catch {
        Write-ColorText "❌ 隧道创建失败: $($_.Exception.Message)" "Red"
    }
}

function Create-TunnelConfig {
    param([string]$TunnelName)
    
    $configDir = "$env:USERPROFILE\.cloudflared"
    $configFile = "$configDir\config.yml"
    
    if (!(Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }
    
    # 获取隧道ID
    $tunnelInfo = & cloudflared tunnel list | Select-String $TunnelName
    if ($tunnelInfo) {
        $tunnelId = ($tunnelInfo -split '\s+')[0]
        
        $configContent = @"
tunnel: $tunnelId
credentials-file: $configDir\$tunnelId.json

ingress:
  - hostname: $TunnelName.trycloudflare.com
    service: http://localhost:$Port
  - service: http_status:404
"@
        
        Set-Content -Path $configFile -Value $configContent -Encoding UTF8
        Write-ColorText "✅ 配置文件已创建: $configFile" "Green"
        Write-ColorText "🌐 隧道地址: https://$TunnelName.trycloudflare.com" "Cyan"
    }
}

function Start-Tunnel {
    param([string]$Name)
    
    Write-ColorText "🚀 启动隧道: $Name" "Cyan"
    
    # 检查本地服务
    $portCheck = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue
    if (!$portCheck) {
        Write-ColorText "⚠️  警告: 端口 $Port 没有服务在运行" "Yellow"
        Write-ColorText "请先启动MCP代理服务器: npm start" "Yellow"
    }
    
    try {
        Write-ColorText "🌐 启动隧道..." "Yellow"
        Write-Host "按 Ctrl+C 停止隧道" -ForegroundColor Gray
        Write-Host ""
        
        & cloudflared tunnel run $Name
    } catch {
        Write-ColorText "❌ 隧道启动失败: $($_.Exception.Message)" "Red"
    }
}

function Get-TunnelStatus {
    Write-ColorText "📊 检查隧道状态..." "Cyan"
    
    try {
        $tunnels = & cloudflared tunnel list
        Write-ColorText "📋 隧道列表:" "Blue"
        Write-Host $tunnels
        
        # 检查运行中的隧道
        $runningTunnels = Get-Process -Name "cloudflared" -ErrorAction SilentlyContinue
        if ($runningTunnels) {
            Write-ColorText "✅ 发现运行中的隧道进程:" "Green"
            foreach ($process in $runningTunnels) {
                Write-Host "  PID: $($process.Id), 启动时间: $($process.StartTime)" -ForegroundColor Green
            }
        } else {
            Write-ColorText "❌ 没有运行中的隧道" "Red"
        }
    } catch {
        Write-ColorText "❌ 无法获取隧道状态: $($_.Exception.Message)" "Red"
    }
}

function Stop-Tunnel {
    Write-ColorText "🛑 停止隧道..." "Cyan"
    
    $cloudflaredProcesses = Get-Process -Name "cloudflared" -ErrorAction SilentlyContinue
    
    if ($cloudflaredProcesses) {
        foreach ($process in $cloudflaredProcesses) {
            Stop-Process -Id $process.Id -Force
            Write-ColorText "✅ 已停止隧道进程 (PID: $($process.Id))" "Green"
        }
    } else {
        Write-ColorText "ℹ️  没有运行中的隧道进程" "Blue"
    }
}

# 主执行逻辑
if ($Help) {
    Show-Help
    exit 0
}

if ($Install) {
    Install-Cloudflared
    exit 0
}

if ($Login) {
    Login-Cloudflare
    exit 0
}

if ($Create) {
    Create-Tunnel -Name $TunnelName
    exit 0
}

if ($Start) {
    Start-Tunnel -Name $TunnelName
    exit 0
}

if ($Stop) {
    Stop-Tunnel
    exit 0
}

if ($Status) {
    Get-TunnelStatus
    exit 0
}

# 默认显示帮助
Show-Help