# Comprehensive test to verify device persistence
$testJsonPath = Join-Path $PSScriptRoot 'devices-persistence-test.json'

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Device Persistence Test" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Clean up any existing test file
if (Test-Path $testJsonPath) {
    Remove-Item $testJsonPath -Force
}

# Initialize with empty array
'[]' | Set-Content $testJsonPath -Encoding UTF8
Write-Host "✓ Created empty devices file" -ForegroundColor Green

# Simulate the script's device loading
$loadedDevices = Get-Content $testJsonPath -Raw | ConvertFrom-Json
$script:devices = @($loadedDevices | ForEach-Object {
    $_ | Add-Member -NotePropertyName ConsecutiveFailures -NotePropertyValue 0 -Force
    $_ | Add-Member -NotePropertyName LastPingTime -NotePropertyValue '' -Force
    $_
})
if (-not $script:devices) { $script:devices = @() }

Write-Host "✓ Loaded devices (count: $($script:devices.Count))" -ForegroundColor Green
Write-Host ""

# Simulate Save-Devices function
function Save-Devices {
    param([string]$path)
    $deviceArray = @($script:devices | Select-Object Name,Address,Ticket,Status,ConsecutiveFailures,Interval,LastPingTime)
    
    if ($deviceArray.Count -eq 0) {
        $json = '[]'
    } elseif ($deviceArray.Count -eq 1) {
        $json = '[' + ($deviceArray | ConvertTo-Json -Depth 3) + ']'
    } else {
        $json = $deviceArray | ConvertTo-Json -Depth 3
    }
    
    $json | Set-Content $path -Encoding UTF8 -Force
}

# Test 1: Add first device
Write-Host "TEST 1: Adding first device..." -ForegroundColor Yellow
$script:devices += [PSCustomObject]@{Name='TEST-DEVICE-1';Address='10.0.0.1';Ticket='INC001';Status='Unknown';ConsecutiveFailures=0;Interval=30;LastPingTime=''}
Save-Devices -path $testJsonPath
Write-Host "  Devices in memory: $($script:devices.Count)" -ForegroundColor Cyan
$reloaded1 = @(Get-Content $testJsonPath -Raw | ConvertFrom-Json)
Write-Host "  Devices in JSON: $($reloaded1.Count)" -ForegroundColor Cyan
if ($reloaded1.Count -eq 1) { Write-Host "  ✓ PASS" -ForegroundColor Green } else { Write-Host "  ✗ FAIL" -ForegroundColor Red }
Write-Host ""

# Test 2: Add second device
Write-Host "TEST 2: Adding second device..." -ForegroundColor Yellow
$script:devices += [PSCustomObject]@{Name='TEST-DEVICE-2';Address='10.0.0.2';Ticket='INC002';Status='Unknown';ConsecutiveFailures=0;Interval=30;LastPingTime=''}
Save-Devices -path $testJsonPath
Write-Host "  Devices in memory: $($script:devices.Count)" -ForegroundColor Cyan
$reloaded2 = @(Get-Content $testJsonPath -Raw | ConvertFrom-Json)
Write-Host "  Devices in JSON: $($reloaded2.Count)" -ForegroundColor Cyan
if ($reloaded2.Count -eq 2) { Write-Host "  ✓ PASS" -ForegroundColor Green } else { Write-Host "  ✗ FAIL" -ForegroundColor Red }
Write-Host ""

# Test 3: Add third device
Write-Host "TEST 3: Adding third device..." -ForegroundColor Yellow
$script:devices += [PSCustomObject]@{Name='TEST-DEVICE-3';Address='10.0.0.3';Ticket='INC003';Status='Unknown';ConsecutiveFailures=0;Interval=30;LastPingTime=''}
Save-Devices -path $testJsonPath
Write-Host "  Devices in memory: $($script:devices.Count)" -ForegroundColor Cyan
$reloaded3 = @(Get-Content $testJsonPath -Raw | ConvertFrom-Json)
Write-Host "  Devices in JSON: $($reloaded3.Count)" -ForegroundColor Cyan
if ($reloaded3.Count -eq 3) { Write-Host "  ✓ PASS" -ForegroundColor Green } else { Write-Host "  ✗ FAIL" -ForegroundColor Red }
Write-Host ""

# Test 4: Simulate app restart - reload from file
Write-Host "TEST 4: Simulating app restart (reload from file)..." -ForegroundColor Yellow
$script:devices = $null
$loadedDevices = Get-Content $testJsonPath -Raw | ConvertFrom-Json
$script:devices = @($loadedDevices | ForEach-Object {
    $_ | Add-Member -NotePropertyName ConsecutiveFailures -NotePropertyValue 0 -Force
    $_ | Add-Member -NotePropertyName LastPingTime -NotePropertyValue '' -Force
    $_
})
Write-Host "  Devices after reload: $($script:devices.Count)" -ForegroundColor Cyan
if ($script:devices.Count -eq 3) { 
    Write-Host "  ✓ PASS - All devices persisted!" -ForegroundColor Green 
    Write-Host "  Devices loaded:" -ForegroundColor Cyan
    $script:devices | ForEach-Object { Write-Host "    - $($_.Name) ($($_.Address)) - Ticket: $($_.Ticket)" -ForegroundColor White }
} else { 
    Write-Host "  ✗ FAIL - Lost devices on reload!" -ForegroundColor Red 
}
Write-Host ""

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Test Complete" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan

# Clean up
if (Test-Path $testJsonPath) {
    Remove-Item $testJsonPath -Force
    Write-Host "`n✓ Cleaned up test file" -ForegroundColor Green
}
