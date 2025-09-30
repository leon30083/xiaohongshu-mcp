# 小红书MCP API调用函数
function Invoke-XiaohongshuAPI {
    param(
        [string]$Action,
        [hashtable]$Parameters = @{}
    )
    
    $baseUrl = "http://100.73.120.70:18060"
    
    switch ($Action) {
        "CheckLogin" {
            $response = Invoke-RestMethod -Uri "$baseUrl/health" -Method GET
            return $response
        }
        "SearchFeeds" {
            $body = @{ keyword = $Parameters.keyword } | ConvertTo-Json
            $response = Invoke-RestMethod -Uri "$baseUrl/api/search" -Method POST -Body $body -ContentType "application/json"
            return $response
        }
        "GetFeedDetail" {
            $body = @{ 
                feed_id = $Parameters.feed_id
                xsec_token = $Parameters.xsec_token 
            } | ConvertTo-Json
            $response = Invoke-RestMethod -Uri "$baseUrl/api/feed/detail" -Method POST -Body $body -ContentType "application/json"
            return $response
        }
        default {
            throw "不支持的操作: $Action"
        }
    }
}

# 测试API调用
Write-Host "测试直接API调用..." -ForegroundColor Yellow
try {
    $result = Invoke-XiaohongshuAPI -Action "CheckLogin"
    Write-Host " 直接API调用成功!" -ForegroundColor Green
    Write-Host "账号: $($result.data.account)" -ForegroundColor Cyan
    Write-Host "状态: $($result.data.status)" -ForegroundColor Cyan
} catch {
    Write-Host " API调用失败: $($_.Exception.Message)" -ForegroundColor Red
}
