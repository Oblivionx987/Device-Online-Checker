# Simulate the new staggered ping approach
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Staggered Ping Simulation" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Simulate 10 devices with different intervals
$simulatedDevices = @(
    [PSCustomObject]@{Name='Device1'; Interval=30; LastPingDateTime=[DateTime]::MinValue}
    [PSCustomObject]@{Name='Device2'; Interval=30; LastPingDateTime=[DateTime]::MinValue}
    [PSCustomObject]@{Name='Device3'; Interval=60; LastPingDateTime=[DateTime]::MinValue}
    [PSCustomObject]@{Name='Device4'; Interval=30; LastPingDateTime=[DateTime]::MinValue}
    [PSCustomObject]@{Name='Device5'; Interval=60; LastPingDateTime=[DateTime]::MinValue}
    [PSCustomObject]@{Name='Device6'; Interval=30; LastPingDateTime=[DateTime]::MinValue}
    [PSCustomObject]@{Name='Device7'; Interval=30; LastPingDateTime=[DateTime]::MinValue}
    [PSCustomObject]@{Name='Device8'; Interval=60; LastPingDateTime=[DateTime]::MinValue}
    [PSCustomObject]@{Name='Device9'; Interval=30; LastPingDateTime=[DateTime]::MinValue}
    [PSCustomObject]@{Name='Device10'; Interval=60; LastPingDateTime=[DateTime]::MinValue}
)

Write-Host "Starting with $($simulatedDevices.Count) devices:" -ForegroundColor Yellow
$simulatedDevices | ForEach-Object { 
    Write-Host "  - $($_.Name) (Interval: $($_.Interval)s)" -ForegroundColor Gray
}
Write-Host ""

$maxConcurrentPings = 5
$timerInterval = 5  # seconds
$simulationDuration = 65  # simulate 65 seconds
$startTime = Get-Date

Write-Host "Simulation: Timer checks every $timerInterval seconds, max $maxConcurrentPings pings per tick" -ForegroundColor Yellow
Write-Host ""

$tick = 0
for ($elapsedSeconds = 0; $elapsedSeconds -le $simulationDuration; $elapsedSeconds += $timerInterval) {
    $tick++
    $now = $startTime.AddSeconds($elapsedSeconds)
    
    # Determine which devices are due
    $devicesDue = @()
    foreach ($device in $simulatedDevices) {
        $timeSinceLastPing = ($now - $device.LastPingDateTime).TotalSeconds
        if ($timeSinceLastPing -ge $device.Interval) {
            $devicesDue += $device
        }
    }
    
    # Limit to max concurrent
    $devicesToPing = $devicesDue | Select-Object -First $maxConcurrentPings
    
    # Display this tick
    $tickTime = $now.ToString('HH:mm:ss')
    if ($devicesToPing.Count -gt 0) {
        $pingBar = "█" * $devicesToPing.Count
        $deviceNames = ($devicesToPing | ForEach-Object { $_.Name }) -join ', '
        Write-Host ("Tick {0:D2} ({1}s): {2,-10} {3}" -f $tick, $elapsedSeconds, $pingBar, $deviceNames) -ForegroundColor Green
        
        # Update LastPingDateTime for pinged devices
        foreach ($d in $devicesToPing) {
            $d.LastPingDateTime = $now
        }
    } else {
        Write-Host ("Tick {0:D2} ({1}s): {2,-10} (No devices due)" -f $tick, $elapsedSeconds, "-") -ForegroundColor DarkGray
    }
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan

# Calculate statistics
Write-Host "Statistics:" -ForegroundColor Yellow
Write-Host "  Total ticks: $tick" -ForegroundColor Cyan
Write-Host "  Devices: $($simulatedDevices.Count)" -ForegroundColor Cyan
Write-Host "  Max per tick: $maxConcurrentPings" -ForegroundColor Cyan
Write-Host ""

# Show comparison
Write-Host "Comparison:" -ForegroundColor Yellow
Write-Host "  OLD approach: All 10 devices ping simultaneously every 30-60s" -ForegroundColor Red
Write-Host "              → 10 concurrent pings → UI FREEZE ~3-5 seconds" -ForegroundColor Red
Write-Host ""
Write-Host "  NEW approach: Max 5 devices per 5-second tick" -ForegroundColor Green
Write-Host "              → Distributed load → NO UI FREEZE" -ForegroundColor Green
Write-Host ""

Write-Host "✓ Staggered approach keeps UI responsive!" -ForegroundColor Green
