# Ngrok内网穿透设置脚本
# 适用于快速测试和开发环境

param(
    [switch]$Install,
    [switch]$Start,
    [switch]$Stop,
    [switch]$Status,
    [switch]$Help,
    [string]$AuthToken = "",
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
    Write-ColorText "=== Ngrok内网穿透工具 ===" "Cyan"
    Write-Host ""
    Write-ColorText "用法:" "Yellow"
    Write-Host "  .\ngrok-setup.ps1 [选项]"
    Write-Host ""
    Write-ColorText "选项:" "Yellow"
    Write-Host "  -Install              安装ngrok"
    Write-Host "  -Start                启动ngrok隧道"
    Write-Host "  -Stop                 停止ngrok隧道"
    Write-Host "  -Status               查看ngrok状态"
    Write-Host "  -AuthToken <token>    设置认证令牌"
    Write-Host "  -Port <port>          指定端口（默认8080）"
    Write-Host "  -Help                 显示帮助"
    Write-Host ""
    Write-ColorText "示例:" "Green"
    Write-Host "  .\ngrok-setup.ps1 -Install"
    Write-Host "  .\ngrok-setup.ps1 -AuthToken 'your_token_here'"
    Write-Host "  .\ngrok-setup.ps1 -Start -Port 8080"
    Write-Host ""
    Write-ColorText "获取AuthToken:" "Yellow"
    Write-Host "  1. 访问 https://ngrok.com/"
    Write-Host "  2. 注册账号"
    Write-Host "  3. 在Dashboard中获取AuthToken"
}

function Install-Ngrok {
    Write-ColorText "🔽 安装Ngrok..." "Cyan"
    
    # 检查是否已安装
    if (Get-Command ngrok -ErrorAction SilentlyContinue) {
        Write-ColorText "✅ Ngrok已安装" "Green"
        return
    }
    
    # 检查是否有Chocolatey
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-ColorText "📦 使用Chocolatey安装Ngrok..." "Yellow"
        choco install ngrok -y
    } else {
        Write-ColorText "📥 下载Ngrok..." "Yellow"
        $downloadUrl = "https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-windows-amd64.zip"
        $zipPath = "$env:TEMP\ngrok.zip"
        $extractPath = "$env:LOCALAPPDATA\ngrok"
        
        # 创建目录
        if (!(Test-Path $extractPath)) {
            New-Item -ItemType Directory -Path $extractPath -Force | Out-Null
        }
        
        # 下载
        Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath
        
        # 解压
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
        
        # 添加到PATH
        $currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
        if ($currentPath -notlike "*$extractPath*") {
            [Environment]::SetEnvironmentVariable("PATH", "$currentPath;$extractPath", "User")
            $env:PATH += ";$extractPath"
        }
        
        # 清理
        Remove-Item $zipPath -Force
        
        Write-ColorText "✅ Ngrok安装完成" "Green"
    }
}

function Set-NgrokAuth {
    param([string]$Token)
    
    if ([string]::IsNullOrEmpty($Token)) {
        Write-ColorText "❌ 请提供AuthToken" "Red"
        Write-ColorText "获取方法: https://ngrok.com/ -> 注册 -> Dashboard -> AuthToken" "Yellow"
        return $false
    }
    
    Write-ColorText "🔑 设置Ngrok认证令牌..." "Cyan"
    
    try {
        & ngrok config add-authtoken $Token
        Write-ColorText "✅ 认证令牌设置成功" "Green"
        return $true
    } catch {
        Write-ColorText "❌ 认证令牌设置失败: $($_.Exception.Message)" "Red"
        return $false
    }
}

function Start-NgrokTunnel {
    param([int]$Port)
    
    Write-ColorText "🚀 启动Ngrok隧道 (端口: $Port)..." "Cyan"
    
    # 检查端口是否被占用
    $portCheck = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue
    if (!$portCheck) {
        Write-ColorText "⚠️  警告: 端口 $Port 没有服务在运行" "Yellow"
        Write-ColorText "请先启动MCP代理服务器: npm start" "Yellow"
    }
    
    # 启动ngrok
    Write-ColorText "🌐 启动隧道..." "Yellow"
    Write-Host "按 Ctrl+C 停止隧道" -ForegroundColor Gray
    Write-Host ""
    
    & ngrok http $Port
}

function Get-NgrokStatus {
    Write-ColorText "📊 检查Ngrok状态..." "Cyan"
    
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:4040/api/tunnels" -ErrorAction Stop
        
        if ($response.tunnels.Count -gt 0) {
            Write-ColorText "✅ Ngrok隧道运行中:" "Green"
            foreach ($tunnel in $response.tunnels) {
                Write-Host "  🌐 公网地址: $($tunnel.public_url)" -ForegroundColor Green
                Write-Host "  🏠 本地地址: $($tunnel.config.addr)" -ForegroundColor Blue
                Write-Host "  📊 连接数: $($tunnel.metrics.conns.count)" -ForegroundColor Yellow
                Write-Host ""
            }
            
            Write-ColorText "🔗 Ngrok Web界面: http://localhost:4040" "Cyan"
        } else {
            Write-ColorText "❌ 没有活动的隧道" "Red"
        }
    } catch {
        Write-ColorText "❌ Ngrok未运行或API不可用" "Red"
        Write-ColorText "请先启动隧道: .\ngrok-setup.ps1 -Start" "Yellow"
    }
}

function Stop-NgrokTunnel {
    Write-ColorText "🛑 停止Ngrok隧道..." "Cyan"
    
    # 查找ngrok进程
    $ngrokProcesses = Get-Process -Name "ngrok" -ErrorAction SilentlyContinue
    
    if ($ngrokProcesses) {
        foreach ($process in $ngrokProcesses) {
            Stop-Process -Id $process.Id -Force
            Write-ColorText "✅ 已停止Ngrok进程 (PID: $($process.Id))" "Green"
        }
    } else {
        Write-ColorText "ℹ️  没有运行中的Ngrok进程" "Blue"
    }
}

# 主执行逻辑
if ($Help) {
    Show-Help
    exit 0
}

if ($Install) {
    Install-Ngrok
    exit 0
}

if ($AuthToken) {
    Set-NgrokAuth -Token $AuthToken
    exit 0
}

if ($Start) {
    Start-NgrokTunnel -Port $Port
    exit 0
}

if ($Stop) {
    Stop-NgrokTunnel
    exit 0
}

if ($Status) {
    Get-NgrokStatus
    exit 0
}

# 默认显示帮助
Show-Help