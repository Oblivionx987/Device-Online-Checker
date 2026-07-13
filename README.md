#Device_Online_Checker


# Device Online Checker

Monitor device reachability via ping with a responsive Windows Forms GUI, per‑device intervals, and optional toast notifications when devices come back online. This README consolidates the information previously in:

- PERFORMANCE-IMPROVEMENTS.md
- STAGGERED-PING-EXPLAINED.md
- PS51-COMPATIBILITY.md
- TOAST-TROUBLESHOOTING.md

## Requirements and Compatibility

- Script Version: 5.1.0+
- Minimum PowerShell Version: 5.1
- Tested on: PowerShell 5.1, 7.5.4
- Optional: BurntToast module for Windows toast notifications
  - Install: `Install-Module -Name BurntToast -Scope CurrentUser -Force`

## Overview

- Per‑device interval tracking prevents large bursts of pings.
- Fast timer tick (every 5 seconds) checks which devices are due.
- Limit of 5 devices pinged per tick to keep the UI responsive.
- Optimized saves: the app only persists when devices were actually pinged.
- Status bar shows transitions and toast activity (v5.2.1+).

## How It Works (Staggered Ping)

- Timer ticks every 5 seconds.
- Each tick determines which devices are due based on each device's `Interval` and `LastPingDateTime`.
- Up to 5 devices are pinged per tick; remainder wait for the next tick.
- Devices added at different times naturally distribute load.

Example timeline (new behavior):

```text
Second 0:  Check all devices → Device1, Device2 due → Ping 2 devices
Second 5:  Check all devices → Device3 due → Ping 1 device
Second 10: Check all devices → Device4, Device5 due → Ping 2 devices
Second 15: Check all devices → None due → Skip this tick
Second 20: Check all devices → Device6 due → Ping 1 device
...
```

Smart scheduling example:

```powershell
# Device with 30s interval, last pinged at 09:00:00
# Timer checks:
09:00:05 → 5s elapsed  < 30s → Skip
09:00:10 → 10s elapsed < 30s → Skip
09:00:30 → 30s elapsed = 30s → PING!
09:00:35 → 5s elapsed  < 30s → Skip (just pinged)
```

## Performance Improvements (v5.2.0)

- Problem (before): All devices pinged together every 30–60s, freezing the UI for 2–5s with 7+ devices.
- Solution (now): Max 5 devices per 5‑second tick with per‑device interval tracking.

Before v5.2.0:

```text
❌ 10 devices all ping every 30s
❌ UI freezes for 3–5 seconds
❌ Network burst of 10 pings
❌ User can't interact during ping
```

After v5.2.0:

```text
✅ 5 devices max per tick
✅ No noticeable UI delay
✅ Gradual network load
✅ App remains responsive
```

Scalability:

| Devices | Old Approach           | New Approach          |
|---------|------------------------|-----------------------|
| 10      | 10 @ once = FREEZE     | 5 per tick = smooth   |
| 50      | 50 @ once = CRASH      | 5 per tick = smooth   |
| 100     | Unusable               | 5 per tick = smooth   |

Note: With 100 devices all at 30s interval, if all are due at once it can take up to 100s to ping all; in practice they naturally stagger.

Benefits:

1. Responsive UI, even with many devices
2. Efficient and fair scheduling per device interval
3. Scalable to large deployments
4. Network‑friendly (no ping storms)
5. Reduced CPU and disk I/O

Upgrade notes:

- Existing `devices.json` works immediately.
- First run may ping all devices (they start "overdue").
- Normal staggering begins after the first cycle.

Technical details (as described):

- Key changes: `LastPingDateTime`, fixed 5s timer, filter by elapsed time, early return, conditional saves.
- Code locations: `Invoke-PingBatch` (lines 183–253), timer setup (256–257), device init (49–54).

## Toast Notifications

Toast triggers when a device transitions from Offline → Online.

Important: A device becomes Offline only after 3 consecutive ping failures. With a 5s tick, that typically takes ~15s before the status flips to Offline. Only when the next successful ping occurs does the toast fire.

Testing toasts:

- Method 1 (recommended):
  1) Disconnect a device
  2) Wait until the Status column shows "Offline" in red (~15–20s)
  3) Reconnect the device
  4) Watch the status bar; toast should appear when it changes to Online
- Method 2: Use a device already marked Offline, power it on, wait for next ping
- Method 3: Manual test script: `.\Testing\Test-Toast.ps1`

Visual indicators (v5.2.1+):

1. Status transitions, e.g. `[10:30:15] SNC49844: Online → Offline`
2. Toast triggers, e.g. `🔔 [10:30:45] Toast: SNC49844 back online!`
3. BurntToast issues, e.g. `[10:30:45] BurntToast not installed - sound played ...`

Common issues:

- Took device offline but no toast appeared
  - Cause: Did not reach true Offline (needs 3 failures)
  - Fix: Wait ~15–20 seconds and confirm red Offline status first
- Status bar says BurntToast not installed
  - Fix: `Install-Module -Name BurntToast -Scope CurrentUser -Force`
  - Fallback: System sound plays instead of toast
- Toast shows but you don’t see it
  - Check Action Center and Windows notification settings
- Nothing happens at all
  - Launch from a PowerShell console and watch Write-Host output; verify device truly hit Offline

Expected behavior timeline (example, 60s interval):

```text
Time      Event                           ConsecutiveFails  Status    Toast?
────────────────────────────────────────────────────────────────────────────
10:00:00  Device unplugged                0                Online    No
10:00:05  Timer tick - ping fails         1                Online    No
10:00:10  Timer tick - ping fails         2                Online    No
10:00:15  Timer tick - ping fails         3                Offline   No
          Status bar: "Device1: Online → Offline"
10:00:45  Device plugged back in          3                Offline   No
10:00:50  Timer tick - ping succeeds      0                Online    YES! 🔔
          Status bar: "🔔 Toast: Device1 back online!"
          Toast notification appears
```

Verification checklist:

- Device showed Offline (red) before reconnecting
- At least ~15 seconds elapsed while disconnected
- Status bar shows transitions
- If using BurntToast, it is installed: `Get-Module -ListAvailable BurntToast`
- Windows notifications are enabled

Advanced debugging:

```powershell
cd "\\sncorp\internal\Corp_Software\ServiceCenter_SNC_Software\Admin_Tools\DeviceOnlineChecker"
.\DeviceOnlineChecker_V3.ps1
```

You should see console output including state transitions and toast trigger lines.

Quick test:

```powershell
.\Testing\Test-Toast-Logic.ps1
```

## Configuration

Adjustable parameters (illustrative):

```powershell
# Timer check frequency (lower = more responsive, higher = less CPU)
$timer.Interval = 5000  # 5 seconds

# Max concurrent pings per tick (lower = less load, higher = faster updates)
$maxConcurrentPings = 5

# Ping timeout per device
$ping.Send($target, 2000)  # 2 seconds

# Failures required for Offline
$PingCount = 3
```

## PowerShell 5.1 Compatibility

Changes for PS 5.1:

- Replaced `Test-Connection -TimeoutSeconds` with the .NET `System.Net.NetworkInformation.Ping` class:

```powershell
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
```

- JSON array handling ensures single-item arrays are saved as arrays:

```powershell
if ($deviceArray.Count -eq 1) {
    $json = '[' + ($deviceArray | ConvertTo-Json -Depth 3) + ']'
} else {
    $json = $deviceArray | ConvertTo-Json -Depth 3
}
```

- Added retry logic for file saves to mitigate transient file locks.

Features verified compatible on PS 5.1:

- Windows Forms GUI (including hashtable splatting)
- Constructor syntax `[Type]::new()` (PS 5.0+)
- Runspace pools for parallel processing
- Manual array handling for JSON persistence
- BurntToast notifications (optional)
- .NET Ping class with a 2s timeout

## Files and Scripts

### Top-level

- `DeviceOnlineChecker_V3.ps1` — Main Windows Forms app for monitoring device reachability.
- `Start_DSC.bat` — Convenience launcher for the Device Online Checker.
- `devices.json` — Primary persistent device store used by the app.
- `devices-test.json` — Sample dataset for testing scenarios.
- `devices-test2.json` — Alternate sample dataset for testing.
- `Testing/` — Collection of test scripts and simulators (see below).

### Testing/

- `Test-Staggered-Ping.ps1` — Simulates the staggered scheduler over time.
- `Test-PS51-Compatibility.ps1` — Verifies PowerShell 5.1 compatibility of features.
- `Test-Ping-PS51.ps1` — Tests .NET Ping-based implementation and timeout behavior.
- `Test-Verify-Persistence.ps1` — Validates device persistence across saves/loads.
- `Test-MultiDevice-Save.ps1` — Stress test for concurrent saves and file-lock handling.
- `Test-SaveDevices.ps1` — Exercises Save-Devices logic for edge cases.
- `Test-Toast.ps1` — Sends a sample toast to confirm notifications or fallback.
- `Test-Toast-Logic.ps1` — Walkthrough of offline/online transitions and toast triggers.

## Testing

- Staggered scheduling simulation: `.\Testing\Test-Staggered-Ping.ps1`
- PS 5.1 compatibility: `.\Testing\Test-PS51-Compatibility.ps1`
- Ping implementation test: `.\Testing\Test-Ping-PS51.ps1`
- Persistence verification: `.\Testing\Test-Verify-Persistence.ps1`
- Multi-device save stress: `.\Testing\Test-MultiDevice-Save.ps1`
- SaveDevices behavior: `.\Testing\Test-SaveDevices.ps1`
- Toast module test: `.\Testing\Test-Toast.ps1`
- Toast logic walkthrough: `.\Testing\Test-Toast-Logic.ps1`

## Deployment

- Works on Windows 10/11 and Windows Server 2016+ (built-in PowerShell 5.1)
- Any system with PowerShell 5.1 or higher
- BurntToast is optional; falls back to a system sound if unavailable

## Future Enhancements

- Configurable `$maxConcurrentPings` via UI
- Priority system (important devices ping first)
- Adaptive timing (slower when no changes)
- Statistics dashboard (pings/minute, etc.)

---

This README consolidates prior documentation. If you’re satisfied, the original Markdown files can be removed from the repository.
