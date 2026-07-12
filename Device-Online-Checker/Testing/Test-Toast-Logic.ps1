# Test the toast notification trigger logic
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Toast Notification Logic Test" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Simulate the status transition logic
$PingCount = 3

function Test-StatusTransition($name, $startStatus, $pingResults) {
    Write-Host "`nTesting: $name" -ForegroundColor Yellow
    Write-Host "  Starting Status: $startStatus" -ForegroundColor Gray
    Write-Host "  Ping Results: $($pingResults -join ', ')" -ForegroundColor Gray
    Write-Host ""
    
    $device = [PSCustomObject]@{
        Name = $name
        Status = $startStatus
        ConsecutiveFailures = 0
    }
    
    $rowTag = $startStatus  # Simulates $row.Tag
    
    foreach ($online in $pingResults) {
        $prev = $rowTag
        
        # This is the actual logic from the script
        if ($online) {
            $device.ConsecutiveFailures = 0
            $status = 'Online'
        } else {
            $device.ConsecutiveFailures++
            if ($device.ConsecutiveFailures -ge $PingCount) {
                $status = 'Offline'
            } else {
                $status = 'Online'
            }
        }
        
        $pingResult = if($online){'Success'}else{'Fail'}
        $color = if($status -eq 'Online'){'Green'}elseif($status -eq 'Offline'){'Red'}else{'Yellow'}
        
        Write-Host "  Ping: $pingResult → CF=$($device.ConsecutiveFailures) → Status='$status' (prev='$prev')" -ForegroundColor $color
        
        # Check toast condition
        if ($prev -eq 'Offline' -and $status -eq 'Online') {
            Write-Host "    🔔 TOAST TRIGGERED!" -ForegroundColor Green -BackgroundColor Black
        }
        
        # Update for next iteration
        $rowTag = $status
        $device.Status = $status
    }
}

Write-Host "Scenario 1: Device goes offline then comes back online" -ForegroundColor Cyan
Test-StatusTransition "Device1" "Online" @($false, $false, $false, $true)

Write-Host "`n" + "─" * 60
Write-Host "Scenario 2: Device is already offline, then comes online" -ForegroundColor Cyan
Test-StatusTransition "Device2" "Offline" @($true)

Write-Host "`n" + "─" * 60
Write-Host "Scenario 3: Device flaps (1-2 failures, not enough to go offline)" -ForegroundColor Cyan
Test-StatusTransition "Device3" "Online" @($false, $true, $false, $true)

Write-Host "`n" + "─" * 60
Write-Host "Scenario 4: Device goes offline, stays offline, then recovers" -ForegroundColor Cyan
Test-StatusTransition "Device4" "Online" @($false, $false, $false, $false, $false, $true)

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Key Finding:" -ForegroundColor Yellow
Write-Host "  Toast triggers ONLY when prev='Offline' AND status='Online'" -ForegroundColor White
Write-Host "  Device must have 3 consecutive failures to reach 'Offline'" -ForegroundColor White
Write-Host "  Then ONE success brings it back to 'Online' and triggers toast" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
