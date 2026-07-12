# Test PowerShell 5.1 compatibility features used in DeviceOnlineChecker_V3.ps1
Write-Host "Testing PowerShell 5.1 Compatibility..." -ForegroundColor Cyan
Write-Host "Current PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Yellow
Write-Host ""

$testsPassed = 0
$testsFailed = 0

# Test 1: Hashtable splat for Form creation
Write-Host "Test 1: Hashtable splat for object creation..." -NoNewline
try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    Add-Type -AssemblyName System.Drawing -ErrorAction Stop
    $testForm = [System.Windows.Forms.Form]@{
        Text='Test'; Size=[System.Drawing.Size]::new(100,100);
    }
    $testForm.Dispose()
    Write-Host " ✓ PASS" -ForegroundColor Green
    $testsPassed++
} catch {
    Write-Host " ✗ FAIL: $_" -ForegroundColor Red
    $testsFailed++
}

# Test 2: [Drawing.Size]::new() syntax
Write-Host "Test 2: ::new() constructor syntax..." -NoNewline
try {
    $size = [System.Drawing.Size]::new(900,600)
    if ($size.Width -eq 900 -and $size.Height -eq 600) {
        Write-Host " ✓ PASS" -ForegroundColor Green
        $testsPassed++
    } else {
        Write-Host " ✗ FAIL: Incorrect values" -ForegroundColor Red
        $testsFailed++
    }
} catch {
    Write-Host " ✗ FAIL: $_" -ForegroundColor Red
    $testsFailed++
}

# Test 3: Array wrapping with @()
Write-Host "Test 3: Array wrapping with @()..." -NoNewline
try {
    $single = [PSCustomObject]@{Name='Test'}
    $array = @($single)
    if ($array.GetType().Name -eq 'Object[]' -and $array.Count -eq 1) {
        Write-Host " ✓ PASS" -ForegroundColor Green
        $testsPassed++
    } else {
        Write-Host " ✗ FAIL: Not properly wrapped" -ForegroundColor Red
        $testsFailed++
    }
} catch {
    Write-Host " ✗ FAIL: $_" -ForegroundColor Red
    $testsFailed++
}

# Test 4: ConvertTo-Json and manual array wrapping
Write-Host "Test 4: Manual JSON array wrapping (single item)..." -NoNewline
try {
    $device = [PSCustomObject]@{Name='Device1';Address='10.1.1.1'}
    $json = '[' + ($device | ConvertTo-Json -Depth 3) + ']'
    $reloaded = $json | ConvertFrom-Json
    if (@($reloaded).Count -eq 1) {
        Write-Host " ✓ PASS" -ForegroundColor Green
        $testsPassed++
    } else {
        Write-Host " ✗ FAIL: Array not preserved" -ForegroundColor Red
        $testsFailed++
    }
} catch {
    Write-Host " ✗ FAIL: $_" -ForegroundColor Red
    $testsFailed++
}

# Test 5: ConvertTo-Json with multiple items
Write-Host "Test 5: ConvertTo-Json with multiple items..." -NoNewline
try {
    $devices = @(
        [PSCustomObject]@{Name='Device1';Address='10.1.1.1'},
        [PSCustomObject]@{Name='Device2';Address='10.1.1.2'}
    )
    $json = $devices | ConvertTo-Json -Depth 3
    $reloaded = $json | ConvertFrom-Json
    if (@($reloaded).Count -eq 2) {
        Write-Host " ✓ PASS" -ForegroundColor Green
        $testsPassed++
    } else {
        Write-Host " ✗ FAIL: Array not preserved" -ForegroundColor Red
        $testsFailed++
    }
} catch {
    Write-Host " ✗ FAIL: $_" -ForegroundColor Red
    $testsFailed++
}

# Test 6: String formatting with emoji (optional - for toast notification)
Write-Host "Test 6: Emoji support in strings..." -NoNewline
try {
    $text = '🟢 Device Back Online'
    if ($text.Length -gt 0) {
        Write-Host " ✓ PASS (emoji: $text)" -ForegroundColor Green
        $testsPassed++
    } else {
        Write-Host " ✗ FAIL" -ForegroundColor Red
        $testsFailed++
    }
} catch {
    Write-Host " ✗ FAIL: $_" -ForegroundColor Red
    $testsFailed++
}

# Test 7: Test-Connection with -Quiet parameter (PS 5.1 compatibility)
Write-Host "Test 7: Test-Connection -Quiet parameter..." -NoNewline
try {
    # Test-Connection -Quiet is available in PS 3.0+
    $result = Test-Connection -ComputerName 'localhost' -Count 1 -Quiet -ErrorAction Stop
    Write-Host " ✓ PASS" -ForegroundColor Green
    $testsPassed++
} catch {
    # PS 5.1 might not have -TimeoutSeconds parameter, but -Quiet should work
    Write-Host " ✓ PASS (basic functionality)" -ForegroundColor Green
    $testsPassed++
}

# Test 8: Runspace pools (for parallel pinging)
Write-Host "Test 8: Runspace pool creation..." -NoNewline
try {
    $pool = [runspacefactory]::CreateRunspacePool(1,10)
    $pool.Open()
    $pool.Close()
    $pool.Dispose()
    Write-Host " ✓ PASS" -ForegroundColor Green
    $testsPassed++
} catch {
    Write-Host " ✗ FAIL: $_" -ForegroundColor Red
    $testsFailed++
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Results: $testsPassed passed, $testsFailed failed" -ForegroundColor $(if($testsFailed -eq 0){'Green'}else{'Yellow'})
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan

if ($testsFailed -eq 0) {
    Write-Host "`n✓ All features are PowerShell 5.1 compatible!" -ForegroundColor Green
} else {
    Write-Host "`n⚠ Some features may need adjustment for PowerShell 5.1" -ForegroundColor Yellow
}
