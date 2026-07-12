# Test script to diagnose device saving issue
$JsonPath = Join-Path $PSScriptRoot 'devices-test.json'

# Simulate the script's behavior
$script:devices = @()

# Add first device
Write-Host "Adding first device..." -ForegroundColor Yellow
$script:devices += [PSCustomObject]@{Name='Device1';Address='10.1.1.1';Ticket='INC001';Status='Unknown';ConsecutiveFailures=0;Interval=30;LastPingTime=''}
Write-Host "Devices count: $($script:devices.Count)" -ForegroundColor Cyan
Write-Host "Devices type: $($script:devices.GetType().Name)" -ForegroundColor Cyan

# Save after first device
Write-Host "`nSaving after first device..." -ForegroundColor Yellow
@($script:devices) | Select-Object Name,Address,Ticket,Status,ConsecutiveFailures,Interval,LastPingTime |
    ConvertTo-Json -Depth 3 -AsArray | Set-Content $JsonPath -Encoding UTF8
Write-Host "Content of JSON after first device:" -ForegroundColor Green
Get-Content $JsonPath | Write-Host

# Add second device
Write-Host "`nAdding second device..." -ForegroundColor Yellow
$script:devices += [PSCustomObject]@{Name='Device2';Address='10.1.1.2';Ticket='INC002';Status='Unknown';ConsecutiveFailures=0;Interval=30;LastPingTime=''}
Write-Host "Devices count: $($script:devices.Count)" -ForegroundColor Cyan
Write-Host "Devices type: $($script:devices.GetType().Name)" -ForegroundColor Cyan

# Save after second device
Write-Host "`nSaving after second device..." -ForegroundColor Yellow
@($script:devices) | Select-Object Name,Address,Ticket,Status,ConsecutiveFailures,Interval,LastPingTime |
    ConvertTo-Json -Depth 3 -AsArray | Set-Content $JsonPath -Encoding UTF8
Write-Host "Content of JSON after second device:" -ForegroundColor Green
Get-Content $JsonPath | Write-Host

# Add third device
Write-Host "`nAdding third device..." -ForegroundColor Yellow
$script:devices += [PSCustomObject]@{Name='Device3';Address='10.1.1.3';Ticket='INC003';Status='Unknown';ConsecutiveFailures=0;Interval=30;LastPingTime=''}
Write-Host "Devices count: $($script:devices.Count)" -ForegroundColor Cyan

# Save after third device
Write-Host "`nSaving after third device..." -ForegroundColor Yellow
@($script:devices) | Select-Object Name,Address,Ticket,Status,ConsecutiveFailures,Interval,LastPingTime |
    ConvertTo-Json -Depth 3 -AsArray | Set-Content $JsonPath -Encoding UTF8
Write-Host "Content of JSON after third device:" -ForegroundColor Green
Get-Content $JsonPath | Write-Host

Write-Host "`nTest complete. Check devices-test.json" -ForegroundColor Green
