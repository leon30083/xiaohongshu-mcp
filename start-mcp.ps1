# Xiaohongshu MCP Server Startup Script
param(
    [switch]$Build,
    [switch]$Check,
    [switch]$Stop,
    [switch]$Restart,
    [switch]$Help
)

function Write-Info($msg) { Write-Host $msg -ForegroundColor Cyan }
function Write-Success($msg) { Write-Host $msg -ForegroundColor Green }
function Write-Warning($msg) { Write-Host $msg -ForegroundColor Yellow }
function Write-Error($msg) { Write-Host $msg -ForegroundColor Red }

function Show-Help {
    Write-Info "Xiaohongshu MCP Server Management Script"
    Write-Host "========================================"
    Write-Warning "Usage: .\start-mcp.ps1 [Options]"
    Write-Host ""
    Write-Success "Options:"
    Write-Host "  -Build     Build before start"
    Write-Host "  -Check     Check service status only"
    Write-Host "  -Stop      Stop MCP service"
    Write-Host "  -Restart   Restart MCP service"
    Write-Host "  -Help      Show this help"
    Write-Host ""
    Write-Success "Examples:"
    Write-Host "  .\start-mcp.ps1           # Direct start"
    Write-Host "  .\start-mcp.ps1 -Build    # Build and start"
    Write-Host "  .\start-mcp.ps1 -Check    # Check status"
    Write-Host "  .\start-mcp.ps1 -Restart  # Restart service"
}

function Test-MCPService {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:18060/health" -TimeoutSec 5 -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            $content = $response.Content | ConvertFrom-Json
            return @{
                Status = "Running"
                Healthy = $content.success
                Account = $content.data.account
                Service = $content.data.service
            }
        }
    }
    catch {
        return @{ Status = "Stopped"; Healthy = $false }
    }
}

function Stop-MCPService {
    Write-Warning "Stopping MCP service..."
    
    $processes = Get-Process | Where-Object { 
        $_.ProcessName -like "*go*" -or 
        $_.CommandLine -like "*xiaohongshu-mcp*" -or
        $_.CommandLine -like "*server*"
    }
    
    if ($processes) {
        foreach ($proc in $processes) {
            try {
                Write-Host "Terminating process: $($proc.ProcessName) (PID: $($proc.Id))"
                Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
            }
            catch {
                Write-Warning "Cannot terminate process $($proc.Id)"
            }
        }
        Start-Sleep -Seconds 2
    }
    
    Write-Success "MCP service stopped"
}

function Start-MCPService {
    param([bool]$BuildFirst = $false)
    
    Write-Info "Starting Xiaohongshu MCP Server..."
    Write-Host "=================================="
    
    # Check Go environment
    Write-Warning "Checking environment..."
    try {
        $goVersion = go version 2>$null
        Write-Success "Go environment: $goVersion"
    }
    catch {
        Write-Error "Go environment not installed or not in PATH"
        return $false
    }
    
    # Check project dependencies
    if (Test-Path "go.mod") {
        Write-Success "Project dependencies: go.mod exists"
    } else {
        Write-Error "go.mod file not found"
        return $false
    }
    
    # Build if needed
    if ($BuildFirst) {
        Write-Warning "Building project..."
        $buildResult = go build -o xiaohongshu-mcp.exe . 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Build successful"
        } else {
            Write-Error "Build failed: $buildResult"
            return $false
        }
    }
    
    # Start service
    Write-Warning "Starting MCP server..."
    
    if ($BuildFirst -and (Test-Path "xiaohongshu-mcp.exe")) {
        Write-Host "Starting with compiled version..."
        Start-Process -FilePath ".\xiaohongshu-mcp.exe" -ArgumentList "server" -WindowStyle Hidden
    } else {
        Write-Host "Starting in development mode..."
        Start-Process -FilePath "go" -ArgumentList "run", ".", "server" -WindowStyle Hidden
    }
    
    # Wait for service to start
    Write-Warning "Waiting for service to start..."
    $maxRetries = 10
    $retryCount = 0
    
    while ($retryCount -lt $maxRetries) {
        Start-Sleep -Seconds 2
        $status = Test-MCPService
        $retryCount++
        
        if ($status.Status -eq "Running") {
            Write-Success "MCP server started successfully!"
            Write-Info "Service status:"
            Write-Host "   - Status: $($status.Status)"
            Write-Host "   - Healthy: $($status.Healthy)"
            Write-Host "   - Account: $($status.Account)"
            Write-Host "   - Service: $($status.Service)"
            Write-Host "   - Address: http://localhost:18060"
            Write-Host ""
            Write-Success "MCP tools are now available in Trae!"
            return $true
        }
        
        Write-Host "Retry $retryCount/$maxRetries..."
    }
    
    Write-Error "Service startup failed, please check logs"
    return $false
}

# Main logic
if ($Help) {
    Show-Help
    exit 0
}

if ($Check) {
    Write-Info "Checking MCP service status..."
    $status = Test-MCPService
    
    if ($status.Status -eq "Running") {
        Write-Success "MCP service is running"
        Write-Host "   - Health status: $($status.Healthy)"
        Write-Host "   - Account: $($status.Account)"
        Write-Host "   - Service: $($status.Service)"
        Write-Host "   - Access URL: http://localhost:18060"
    } else {
        Write-Error "MCP service is not running"
    }
    exit 0
}

if ($Stop) {
    Stop-MCPService
    exit 0
}

if ($Restart) {
    Write-Info "Restarting MCP service..."
    Stop-MCPService
    Start-Sleep -Seconds 3
    Start-MCPService -BuildFirst $Build
    exit 0
}

# Default startup
Start-MCPService -BuildFirst $Build