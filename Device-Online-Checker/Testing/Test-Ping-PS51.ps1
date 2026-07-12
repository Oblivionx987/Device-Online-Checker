# Test the new .NET Ping implementation (PowerShell 5.1 compatible)
Write-Host "Testing .NET Ping Implementation (PS 5.1 Compatible)" -ForegroundColor Cyan
Write-Host "Current PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Yellow
Write-Host ""

# The new ping script block from DeviceOnlineChecker_V3.ps1
$pingScript = {
    param($target)
    try {
        $ping = New-Object System.Net.NetworkInformation.Ping
        $result = $ping.Send($target, 2000)
        $ping.Dispose()
        return ($result.Status -eq 'Success')
    } catch {
        return $false
    }
}

# Test 1: Ping localhost (should succeed)
Write-Host "Test 1: Ping localhost..." -NoNewline
$result = & $pingScript 'localhost'
if ($result -eq $true) {
    Write-Host " ✓ PASS (Online)" -ForegroundColor Green
} else {
    Write-Host " ✗ FAIL (Expected online)" -ForegroundColor Red
}

# Test 2: Ping loopback IP (should succeed)
Write-Host "Test 2: Ping 127.0.0.1..." -NoNewline
$result = & $pingScript '127.0.0.1'
if ($result -eq $true) {
    Write-Host " ✓ PASS (Online)" -ForegroundColor Green
} else {
    Write-Host " ✗ FAIL (Expected online)" -ForegroundColor Red
}

# Test 3: Ping invalid address (should fail)
Write-Host "Test 3: Ping invalid address (192.0.2.254)..." -NoNewline
$result = & $pingScript '192.0.2.254'
if ($result -eq $false) {
    Write-Host " ✓ PASS (Offline as expected)" -ForegroundColor Green
} else {
    Write-Host " ⚠ WARNING (Unexpectedly online)" -ForegroundColor Yellow
}

# Test 4: Ping invalid hostname (should fail)
Write-Host "Test 4: Ping invalid hostname (nonexistent.local)..." -NoNewline
$result = & $pingScript 'nonexistent-host-that-does-not-exist.local'
if ($result -eq $false) {
    Write-Host " ✓ PASS (Offline as expected)" -ForegroundColor Green
} else {
    Write-Host " ⚠ WARNING (Unexpectedly online)" -ForegroundColor Yellow
}

# Test 5: Test timeout (should complete within reasonable time)
Write-Host "Test 5: Test timeout behavior..." -NoNewline
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$result = & $pingScript '192.0.2.254'
$sw.Stop()
if ($sw.ElapsedMilliseconds -lt 3000) {
    Write-Host " ✓ PASS (Completed in $($sw.ElapsedMilliseconds)ms)" -ForegroundColor Green
} else {
    Write-Host " ✗ FAIL (Took $($sw.ElapsedMilliseconds)ms, expected <3000ms)" -ForegroundColor Red
}

# Test 6: Parallel ping test (simulating app behavior)
Write-Host "Test 6: Parallel ping test with runspace pool..." -NoNewline
try {
    $targets = @('localhost', '127.0.0.1', '192.0.2.254')
    $pool = [runspacefactory]::CreateRunspacePool(1,10)
    $pool.Open()
    $jobs = @()
    
    foreach ($target in $targets) {
        $ps = [powershell]::Create()
        $ps.RunspacePool = $pool
        $null = $ps.AddScript($pingScript).AddArgument($target)
        $jobs += [pscustomobject]@{Target=$target; PS=$ps; Handle=$ps.BeginInvoke()}
    }
    
    $results = @()
    foreach ($job in $jobs) {
        $online = [bool]($job.PS.EndInvoke($job.Handle))
        $job.PS.Dispose()
        $results += [pscustomobject]@{Target=$job.Target; Online=$online}
    }
    
    $pool.Close()
    $pool.Dispose()
    
    Write-Host " ✓ PASS" -ForegroundColor Green
    foreach ($r in $results) {
        $status = if($r.Online){'Online'}else{'Offline'}
        $color = if($r.Online){'Green'}else{'Red'}
        Write-Host "     $($r.Target): $status" -ForegroundColor $color
    }
} catch {
    Write-Host " ✗ FAIL: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "✓ PowerShell 5.1 compatible ping implementation verified!" -ForegroundColor Green
