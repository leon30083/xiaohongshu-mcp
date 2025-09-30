# Multi-Tunnel Solution for Dual Router Network Environment
Write-Host "Multi-Tunnel Solution Starting..." -ForegroundColor Green

# Check service status
function Test-ServiceRunning {
    param($Port, $ServiceName)
    try {
        $result = Test-NetConnection -ComputerName localhost -Port $Port -WarningAction SilentlyContinue
        if ($result.TcpTestSucceeded) {
            Write-Host "Service $ServiceName is running on port $Port" -ForegroundColor Green
            return $true
        } else {
            Write-Host "Service $ServiceName is NOT running on port $Port" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "Failed to check $ServiceName on port $Port" -ForegroundColor Red
        return $false
    }
}

Write-Host "Checking current service status..." -ForegroundColor Blue
$mcpProxy = Test-ServiceRunning -Port 8080 -ServiceName "MCP Proxy Server"
$mcpLocal = Test-ServiceRunning -Port 18060 -ServiceName "Local MCP Service"

Write-Host ""
Write-Host "Network Environment Analysis:" -ForegroundColor Blue
Write-Host "Local IP: 10.168.1.109 (Secondary Router)" -ForegroundColor Gray
Write-Host "Gateway: 10.168.1.1 (Secondary Router)" -ForegroundColor Gray
Write-Host "Architecture: Internet -> Main Router -> Secondary Router -> Your PC" -ForegroundColor Gray
Write-Host ""

Write-Host "Recommended Solutions (Priority Order):" -ForegroundColor Blue
Write-Host ""

Write-Host "Solution 1: Tailscale Funnel (Most Stable)" -ForegroundColor Yellow
Write-Host "1. Install: winget install tailscale.tailscale" -ForegroundColor White
Write-Host "2. Run: tailscale up" -ForegroundColor White
Write-Host "3. Run: tailscale funnel 8080" -ForegroundColor White
Write-Host "4. Get URL: tailscale funnel status" -ForegroundColor White
Write-Host ""

Write-Host "Solution 2: Ngrok with Auth Token" -ForegroundColor Yellow
Write-Host "1. Visit: https://ngrok.com/signup" -ForegroundColor Cyan
Write-Host "2. Get authtoken" -ForegroundColor White
Write-Host "3. Run: ngrok config add-authtoken YOUR_TOKEN" -ForegroundColor White
Write-Host "4. Run: ngrok http 8080" -ForegroundColor White
Write-Host ""

Write-Host "Solution 3: LocalTunnel (Quick Test)" -ForegroundColor Yellow
Write-Host "1. Install: npm install -g localtunnel" -ForegroundColor White
Write-Host "2. Run: lt --port 8080" -ForegroundColor White
Write-Host ""

Write-Host "Solution 4: Router Port Forwarding" -ForegroundColor Yellow
Write-Host "Main Router: External Port 8080 -> Secondary Router IP:8080" -ForegroundColor White
Write-Host "Secondary Router: External Port 8080 -> 10.168.1.109:8080" -ForegroundColor White
Write-Host ""

Write-Host "Current Cloudflare Tunnel Status:" -ForegroundColor Blue
Write-Host "URL: https://lot-automotive-strict-gray.trycloudflare.com" -ForegroundColor Cyan
Write-Host "Status: Running but may have network path issues" -ForegroundColor Yellow
Write-Host ""

Write-Host "Recommendation: Try Tailscale Funnel first!" -ForegroundColor Green