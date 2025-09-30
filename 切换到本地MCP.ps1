# Switch to Local MCP - Quick Fix Script
# 切换到本地MCP - 快速修复脚本

param(
    [switch]$Help,
    [switch]$Check,
    [switch]$Switch,
    [switch]$Restore
)

# Color output functions
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
    Write-ColorText "=== 小红书MCP本地切换工具 ===" "Cyan"
    Write-Host ""
    Write-ColorText "用法:" "Yellow"
    Write-Host "  .\切换到本地MCP.ps1 [选项]"
    Write-Host ""
    Write-ColorText "选项:" "Yellow"
    Write-Host "  -Check     检查当前MCP配置状态"
    Write-Host "  -Switch    切换到本地MCP配置"
    Write-Host "  -Restore   恢复远程MCP配置"
    Write-Host "  -Help      显示此帮助信息"
    Write-Host ""
    Write-ColorText "示例:" "Green"
    Write-Host "  .\切换到本地MCP.ps1 -Check    # 检查状态"
    Write-Host "  .\切换到本地MCP.ps1 -Switch   # 切换到本地"
    Write-Host ""
}

function Get-TraeConfigPath {
    $appDataPath = $env:APPDATA
    return Join-Path $appDataPath "Trae\mcp.json"
}

function Get-ProjectConfigPath {
    return ".\.trae\mcp.json"
}

function Check-MCPConfig {
    Write-ColorText "🔍 检查MCP配置状态..." "Cyan"
    
    $traeConfig = Get-TraeConfigPath
    $projectConfig = Get-ProjectConfigPath
    
    Write-Host ""
    Write-ColorText "全局配置文件:" "Yellow"
    Write-Host "  路径: $traeConfig"
    
    if (Test-Path $traeConfig) {
        Write-ColorText "  状态: ✅ 存在" "Green"
        try {
            $content = Get-Content $traeConfig -Raw | ConvertFrom-Json
            if ($content.mcpServers."xiaohongshu-mcp") {
                $server = $content.mcpServers."xiaohongshu-mcp"
                Write-Host "  URL: $($server.url)"
                Write-Host "  类型: $($server.type)"
                Write-Host "  状态: $(if ($server.disabled) { '❌ 已禁用' } else { '✅ 已启用' })"
            } else {
                Write-ColorText "  配置: ❌ 未找到xiaohongshu-mcp配置" "Red"
            }
        } catch {
            Write-ColorText "  错误: ❌ 配置文件格式错误" "Red"
        }
    } else {
        Write-ColorText "  状态: ❌ 不存在" "Red"
    }
    
    Write-Host ""
    Write-ColorText "项目配置文件:" "Yellow"
    Write-Host "  路径: $projectConfig"
    
    if (Test-Path $projectConfig) {
        Write-ColorText "  状态: ✅ 存在" "Green"
        try {
            $content = Get-Content $projectConfig -Raw | ConvertFrom-Json
            if ($content.mcpServers."xiaohongshu-mcp") {
                $server = $content.mcpServers."xiaohongshu-mcp"
                Write-Host "  URL: $($server.url)"
                Write-Host "  类型: $($server.type)"
                Write-Host "  状态: $(if ($server.disabled) { '❌ 已禁用' } else { '✅ 已启用' })"
            } else {
                Write-ColorText "  配置: ❌ 未找到xiaohongshu-mcp配置" "Red"
            }
        } catch {
            Write-ColorText "  错误: ❌ 配置文件格式错误" "Red"
        }
    } else {
        Write-ColorText "  状态: ❌ 不存在" "Red"
    }
    
    Write-Host ""
    Write-ColorText "本地MCP服务状态:" "Yellow"
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:18060/health" -TimeoutSec 5 -UseBasicParsing
        if ($response.StatusCode -eq 200) {
            Write-ColorText "  状态: ✅ 本地MCP服务正在运行" "Green"
        }
    } catch {
        Write-ColorText "  状态: ❌ 本地MCP服务未运行" "Red"
        Write-ColorText "  建议: 运行 .\start-mcp.ps1 启动本地服务" "Yellow"
    }
}

function Switch-ToLocal {
    Write-ColorText "🔄 切换到本地MCP配置..." "Cyan"
    
    # 确保.trae目录存在
    if (!(Test-Path ".\.trae")) {
        New-Item -ItemType Directory -Path ".\.trae" -Force | Out-Null
        Write-ColorText "✅ 创建 .trae 目录" "Green"
    }
    
    # 创建本地配置
    $localConfig = @{
        mcpServers = @{
            "xiaohongshu-mcp" = @{
                url = "http://localhost:18060/mcp"
                type = "sse"
                disabled = $false
            }
        }
    }
    
    $projectConfigPath = Get-ProjectConfigPath
    $localConfig | ConvertTo-Json -Depth 10 | Set-Content $projectConfigPath -Encoding UTF8
    Write-ColorText "✅ 创建本地MCP配置文件" "Green"
    
    # 禁用全局配置中的远程MCP
    $traeConfigPath = Get-TraeConfigPath
    if (Test-Path $traeConfigPath) {
        try {
            $traeConfig = Get-Content $traeConfigPath -Raw | ConvertFrom-Json
            if ($traeConfig.mcpServers."xiaohongshu-mcp") {
                $traeConfig.mcpServers."xiaohongshu-mcp".disabled = $true
                $traeConfig | ConvertTo-Json -Depth 10 | Set-Content $traeConfigPath -Encoding UTF8
                Write-ColorText "✅ 禁用全局配置中的远程MCP" "Green"
            }
        } catch {
            Write-ColorText "⚠️  无法修改全局配置，请手动禁用" "Yellow"
        }
    }
    
    Write-Host ""
    Write-ColorText "🎉 切换完成！" "Green"
    Write-ColorText "📝 下一步操作:" "Yellow"
    Write-Host "  1. 启动本地MCP服务: .\start-mcp.ps1"
    Write-Host "  2. 重启Trae IDE以加载新配置"
    Write-Host "  3. 在Trae中测试MCP工具"
}

function Restore-Remote {
    Write-ColorText "🔄 恢复远程MCP配置..." "Cyan"
    
    # 删除本地配置
    $projectConfigPath = Get-ProjectConfigPath
    if (Test-Path $projectConfigPath) {
        Remove-Item $projectConfigPath -Force
        Write-ColorText "✅ 删除本地MCP配置文件" "Green"
    }
    
    # 启用全局配置中的远程MCP
    $traeConfigPath = Get-TraeConfigPath
    if (Test-Path $traeConfigPath) {
        try {
            $traeConfig = Get-Content $traeConfigPath -Raw | ConvertFrom-Json
            if ($traeConfig.mcpServers."xiaohongshu-mcp") {
                $traeConfig.mcpServers."xiaohongshu-mcp".disabled = $false
                $traeConfig | ConvertTo-Json -Depth 10 | Set-Content $traeConfigPath -Encoding UTF8
                Write-ColorText "✅ 启用全局配置中的远程MCP" "Green"
            }
        } catch {
            Write-ColorText "⚠️  无法修改全局配置，请手动启用" "Yellow"
        }
    }
    
    Write-Host ""
    Write-ColorText "🎉 恢复完成！" "Green"
    Write-ColorText "📝 下一步操作:" "Yellow"
    Write-Host "  1. 重启Trae IDE以加载配置"
    Write-Host "  2. 确保远程服务器MCP服务正常运行"
}

# Main execution
if ($Help) {
    Show-Help
    exit 0
}

if ($Check) {
    Check-MCPConfig
    exit 0
}

if ($Switch) {
    Switch-ToLocal
    exit 0
}

if ($Restore) {
    Restore-Remote
    exit 0
}

# Default: show help
Show-Help