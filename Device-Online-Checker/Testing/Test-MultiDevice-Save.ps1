# Test the new Save-Devices function with multiple devices
$JsonPath = Join-Path $PSScriptRoot 'devices-test2.json'

# Import the Save-Devices function (copy from main script)
function Save-Devices {
    $retryCount = 0
    $maxRetries = 3
    $saved = $false
    
    while (-not $saved -and $retryCount -lt $maxRetries) {
        try {
            # Ensure we always have an array structure
            $deviceArray = @($script:devices | Select-Object Name,Address,Ticket,Status,ConsecutiveFailures,Interval,LastPingTime)
            
            # Convert to JSON - wrap in array even if single item
            if ($deviceArray.Count -eq 0) {
                $json = '[]'
            } elseif ($deviceArray.Count -eq 1) {
                # Force array format for single item
                $json = '[' + ($deviceArray | ConvertTo-Json -Depth 3) + ']'
            } else {
                $json = $deviceArray | ConvertTo-Json -Depth 3
            }
            
            # Save with retry logic
            $json | Set-Content $JsonPath -Encoding UTF8 -Force
            $saved = $true
        } catch {
            $retryCount++
            if ($retryCount -lt $maxRetries) {
                Start-Sleep -Milliseconds 50
            }
        }
    }
}

# Test with empty array
Write-Host "Test 1: Empty array" -ForegroundColor Yellow
$script:devices = @()
Save-Devices
Write-Host "Result:" -ForegroundColor Cyan
Get-Content $JsonPath
Write-Host ""

# Test with single device
Write-Host "Test 2: Single device" -ForegroundColor Yellow
$script:devices = @([PSCustomObject]@{Name='Device1';Address='10.1.1.1';Ticket='INC001';Status='Unknown';ConsecutiveFailures=0;Interval=30;LastPingTime=''})
Save-Devices
Write-Host "Result:" -ForegroundColor Cyan
Get-Content $JsonPath
Write-Host ""

# Test with two devices
Write-Host "Test 3: Two devices" -ForegroundColor Yellow
$script:devices += [PSCustomObject]@{Name='Device2';Address='10.1.1.2';Ticket='INC002';Status='Unknown';ConsecutiveFailures=0;Interval=30;LastPingTime=''}
Save-Devices
Write-Host "Result:" -ForegroundColor Cyan
Get-Content $JsonPath
Write-Host ""

# Test with three devices
Write-Host "Test 4: Three devices" -ForegroundColor Yellow
$script:devices += [PSCustomObject]@{Name='Device3';Address='10.1.1.3';Ticket='INC003';Status='Unknown';ConsecutiveFailures=0;Interval=30;LastPingTime=''}
Save-Devices
Write-Host "Result:" -ForegroundColor Cyan
Get-Content $JsonPath
Write-Host ""

# Verify reload
Write-Host "Test 5: Reload from JSON" -ForegroundColor Yellow
$reloaded = Get-Content $JsonPath -Raw | ConvertFrom-Json
Write-Host "Reloaded device count: $(@($reloaded).Count)" -ForegroundColor Green
$reloaded | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor Cyan }

Write-Host "`n✅ All tests complete!" -ForegroundColor Green
