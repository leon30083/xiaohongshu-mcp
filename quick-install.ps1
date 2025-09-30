# xiaohongshu-mcp Trae Quick Install
# Fast installation script - Simplified version

Write-Host "Starting xiaohongshu-mcp Trae installation..." -ForegroundColor Green

# 1. Create config directory
New-Item -ItemType Directory -Path ".\.trae" -Force | Out-Null

# 2. Create MCP configuration
$config = @'
{
    "mcpServers": {
        "xiaohongshu-mcp": {
            "type": "sse",
            "url": "http://localhost:18060/mcp",
            "fromGalleryId": "modelcontextprotocol.servers_xiaohongshu-mcp"
        }
    }
}
'@

$config | Out-File -FilePath ".\.trae\mcp.json" -Encoding UTF8

# 3. Start service
$existing = Get-Process -Name "xiaohongshu-mcp" -ErrorAction SilentlyContinue
if (!$existing) {
    Start-Process -FilePath ".\xiaohongshu-mcp.exe" -ArgumentList "-headless=false" -WindowStyle Hidden
    Start-Sleep -Seconds 3
}

# 4. Verify installation
try {
    $health = Invoke-RestMethod -Uri "http://localhost:18060/health" -TimeoutSec 5
    if ($health.success) {
        Write-Host "Installation successful! Service is running normally" -ForegroundColor Green
        Write-Host "Config file: .\.trae\mcp.json" -ForegroundColor Cyan
        Write-Host "Service URL: http://localhost:18060/mcp" -ForegroundColor Cyan
    }
} catch {
    Write-Host "Service may need a few seconds to start, please verify later" -ForegroundColor Yellow
}

Write-Host "Trae MCP configuration completed!" -ForegroundColor Green