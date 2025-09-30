# FRP内网穿透设置脚本
# 适用于高级用户，需要自己的服务器

param(
    [switch]$Install,
    [switch]$Setup,
    [switch]$Start,
    [switch]$Stop,
    [switch]$Status,
    [switch]$Help,
    [string]$ServerIP = "",
    [int]$ServerPort = 7000,
    [int]$LocalPort = 8080,
    [int]$RemotePort = 8080,
    [string]$Token = ""
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
    Write-ColorText "=== FRP内网穿透设置工具 ===" "Cyan"
    Write-Host ""
    Write-ColorText "用法:" "Yellow"
    Write-Host "  .\frp-setup.ps1 [选项]"
    Write-Host ""
    Write-ColorText "选项:" "Yellow"
    Write-Host "  -Install              下载安装FRP客户端"
    Write-Host "  -Setup                配置FRP客户端"
    Write-Host "  -Start                启动FRP客户端"
    Write-Host "  -Stop                 停止FRP客户端"
    Write-Host "  -Status               查看FRP状态"
    Write-Host "  -ServerIP <ip>        FRP服务器IP地址"
    Write-Host "  -ServerPort <port>    FRP服务器端口（默认: 7000）"
    Write-Host "  -LocalPort <port>     本地服务端口（默认: 8080）"
    Write-Host "  -RemotePort <port>    远程映射端口（默认: 8080）"
    Write-Host "  -Token <token>        连接令牌"
    Write-Host "  -Help                 显示帮助"
    Write-Host ""
    Write-ColorText "完整设置流程:" "Green"
    Write-Host "  1. .\frp-setup.ps1 -Install"
    Write-Host "  2. .\frp-setup.ps1 -Setup -ServerIP <你的服务器IP> -Token <连接令牌>"
    Write-Host "  3. .\frp-setup.ps1 -Start"
    Write-Host ""
    Write-ColorText "前置条件:" "Yellow"
    Write-Host "  1. 拥有一台公网服务器"
    Write-Host "  2. 服务器已安装并运行frps（FRP服务端）"
    Write-Host "  3. 服务器防火墙已开放相应端口"
    Write-Host ""
    Write-ColorText "免费FRP服务器推荐:" "Blue"
    Write-Host "  - Sakura Frp: https://www.natfrp.com/"
    Write-Host "  - OpenFrp: https://www.openfrp.net/"
    Write-Host "  - 自建服务器教程: https://github.com/fatedier/frp"
}

function Install-FRP {
    Write-ColorText "🔽 安装FRP客户端..." "Cyan"
    
    $frpDir = "$env:LOCALAPPDATA\frp"
    $frpcPath = "$frpDir\frpc.exe"
    
    # 检查是否已安装
    if (Test-Path $frpcPath) {
        Write-ColorText "✅ FRP客户端已安装" "Green"
        & $frpcPath version
        return
    }
    
    Write-ColorText "📥 下载FRP..." "Yellow"
    
    # 获取最新版本
    try {
        $latestRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/fatedier/frp/releases/latest"
        $version = $latestRelease.tag_name
        $downloadUrl = "https://github.com/fatedier/frp/releases/download/$version/frp_${version}_windows_amd64.zip"
        
        Write-ColorText "📦 下载版本: $version" "Blue"
        
        # 创建临时目录
        $tempDir = "$env:TEMP\frp_download"
        $zipPath = "$tempDir\frp.zip"
        
        if (!(Test-Path $tempDir)) {
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        }
        
        # 下载
        Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath
        
        # 解压
        Expand-Archive -Path $zipPath -DestinationPath $tempDir -Force
        
        # 查找解压后的目录
        $extractedDir = Get-ChildItem -Path $tempDir -Directory | Where-Object { $_.Name -like "frp_*" } | Select-Object -First 1
        
        if ($extractedDir) {
            # 创建安装目录
            if (!(Test-Path $frpDir)) {
                New-Item -ItemType Directory -Path $frpDir -Force | Out-Null
            }
            
            # 复制文件
            Copy-Item -Path "$($extractedDir.FullName)\frpc.exe" -Destination $frpcPath
            Copy-Item -Path "$($extractedDir.FullName)\frpc.ini" -Destination "$frpDir\frpc.ini"
            
            # 添加到PATH
            $currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
            if ($currentPath -notlike "*$frpDir*") {
                [Environment]::SetEnvironmentVariable("PATH", "$currentPath;$frpDir", "User")
                $env:PATH += ";$frpDir"
            }
            
            Write-ColorText "✅ FRP客户端安装完成" "Green"
            & $frpcPath version
        } else {
            Write-ColorText "❌ 解压失败，找不到FRP文件" "Red"
        }
        
        # 清理临时文件
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        
    } catch {
        Write-ColorText "❌ 安装失败: $($_.Exception.Message)" "Red"
    }
}

function Setup-FRP {
    param(
        [string]$ServerIP,
        [int]$ServerPort,
        [int]$LocalPort,
        [int]$RemotePort,
        [string]$Token
    )
    
    Write-ColorText "⚙️  配置FRP客户端..." "Cyan"
    
    if (!$ServerIP) {
        Write-ColorText "❌ 请提供服务器IP地址" "Red"
        Write-ColorText "用法: .\frp-setup.ps1 -Setup -ServerIP <服务器IP> -Token <令牌>" "Yellow"
        return
    }
    
    $frpDir = "$env:LOCALAPPDATA\frp"
    $configPath = "$frpDir\frpc.ini"
    
    if (!(Test-Path $frpDir)) {
        Write-ColorText "❌ FRP未安装，请先运行: .\frp-setup.ps1 -Install" "Red"
        return
    }
    
    # 生成配置文件
    $configContent = @"
[common]
server_addr = $ServerIP
server_port = $ServerPort
token = $Token

[xiaohongshu-mcp]
type = tcp
local_ip = 127.0.0.1
local_port = $LocalPort
remote_port = $RemotePort
"@
    
    Set-Content -Path $configPath -Value $configContent -Encoding UTF8
    
    Write-ColorText "✅ 配置文件已创建: $configPath" "Green"
    Write-ColorText "📋 配置信息:" "Blue"
    Write-Host "  服务器地址: $ServerIP:$ServerPort" -ForegroundColor White
    Write-Host "  本地端口: $LocalPort" -ForegroundColor White
    Write-Host "  远程端口: $RemotePort" -ForegroundColor White
    Write-Host "  访问地址: http://$ServerIP:$RemotePort" -ForegroundColor Cyan
}

function Start-FRP {
    Write-ColorText "🚀 启动FRP客户端..." "Cyan"
    
    $frpDir = "$env:LOCALAPPDATA\frp"
    $frpcPath = "$frpDir\frpc.exe"
    $configPath = "$frpDir\frpc.ini"
    
    if (!(Test-Path $frpcPath)) {
        Write-ColorText "❌ FRP未安装，请先运行: .\frp-setup.ps1 -Install" "Red"
        return
    }
    
    if (!(Test-Path $configPath)) {
        Write-ColorText "❌ 配置文件不存在，请先运行: .\frp-setup.ps1 -Setup" "Red"
        return
    }
    
    # 检查本地服务
    $portCheck = Get-NetTCPConnection -LocalPort $LocalPort -ErrorAction SilentlyContinue
    if (!$portCheck) {
        Write-ColorText "⚠️  警告: 端口 $LocalPort 没有服务在运行" "Yellow"
        Write-ColorText "请先启动MCP代理服务器: npm start" "Yellow"
    }
    
    try {
        Write-ColorText "🌐 连接FRP服务器..." "Yellow"
        Write-Host "按 Ctrl+C 停止连接" -ForegroundColor Gray
        Write-Host ""
        
        & $frpcPath -c $configPath
    } catch {
        Write-ColorText "❌ FRP启动失败: $($_.Exception.Message)" "Red"
    }
}

function Get-FRPStatus {
    Write-ColorText "📊 检查FRP状态..." "Cyan"
    
    try {
        $frpProcesses = Get-Process -Name "frpc" -ErrorAction SilentlyContinue
        
        if ($frpProcesses) {
            Write-ColorText "✅ FRP客户端正在运行:" "Green"
            foreach ($process in $frpProcesses) {
                Write-Host "  PID: $($process.Id), 启动时间: $($process.StartTime)" -ForegroundColor Green
            }
            
            # 检查配置
            $configPath = "$env:LOCALAPPDATA\frp\frpc.ini"
            if (Test-Path $configPath) {
                Write-ColorText "📋 当前配置:" "Blue"
                $config = Get-Content $configPath
                foreach ($line in $config) {
                    if ($line -match "server_addr|server_port|remote_port") {
                        Write-Host "  $line" -ForegroundColor White
                    }
                }
            }
        } else {
            Write-ColorText "❌ FRP客户端未运行" "Red"
        }
        
        # 检查本地端口
        $portCheck = Get-NetTCPConnection -LocalPort $LocalPort -ErrorAction SilentlyContinue
        if ($portCheck) {
            Write-ColorText "✅ 本地端口 $LocalPort 正在监听" "Green"
        } else {
            Write-ColorText "❌ 本地端口 $LocalPort 未监听" "Red"
        }
        
    } catch {
        Write-ColorText "❌ 无法获取FRP状态: $($_.Exception.Message)" "Red"
    }
}

function Stop-FRP {
    Write-ColorText "🛑 停止FRP客户端..." "Cyan"
    
    $frpProcesses = Get-Process -Name "frpc" -ErrorAction SilentlyContinue
    
    if ($frpProcesses) {
        foreach ($process in $frpProcesses) {
            Stop-Process -Id $process.Id -Force
            Write-ColorText "✅ 已停止FRP进程 (PID: $($process.Id))" "Green"
        }
    } else {
        Write-ColorText "ℹ️  没有运行中的FRP进程" "Blue"
    }
}

# 主执行逻辑
if ($Help) {
    Show-Help
    exit 0
}

if ($Install) {
    Install-FRP
    exit 0
}

if ($Setup) {
    Setup-FRP -ServerIP $ServerIP -ServerPort $ServerPort -LocalPort $LocalPort -RemotePort $RemotePort -Token $Token
    exit 0
}

if ($Start) {
    Start-FRP
    exit 0
}

if ($Stop) {
    Stop-FRP
    exit 0
}

if ($Status) {
    Get-FRPStatus
    exit 0
}

# 默认显示帮助
Show-Help