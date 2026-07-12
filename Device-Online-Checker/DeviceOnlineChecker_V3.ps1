
#Region Execution Policy
Set-ExecutionPolicy -ExecutionPolicy unrestricted -Scope LocalMachine -Force
#EndRegion


#Region SVC Tools Module Import
Import-Module -Name "\\sncorp\internal\Corp_Software\ServiceCenter_SNC_Software\SVCToolsV3_Module\SVCToolsV3.psm1" -ErrorAction SilentlyContinue
#EndRegion

#Region Script Info
$Script_Name = "DeviceOnlineChecker_V3.ps1"
$Description = "This script will check if devices are online at set intervals"
$Author = "Seth Burns - System Administrator II - Service Center"
$ScriptVersion = "5.2.3"
#EndRegion


<#
.SYNOPSIS
    Device Status Monitor – name-only add support + minor UX tweaks.

.DESCRIPTION
    * You can now add a device with **just the Name field**. If the IP/Host box is left
      blank, the script assumes the host address equals the Name you entered.
    * Label updated to clarify “IP/Host (optional)”.
    * All prior features preserved (bottom-docked panel, parallel pings, etc.).

    Example: Type **`fileserver01`** in Name, leave IP/Host blank → row added with
    Name = fileserver01 | Address = fileserver01.

.REQUIREMENTS
    PowerShell 5.1+ (fully compatible). Toasts use BurntToast if installed.
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# -----------------------------------------------------------------------------
# Globals & constants
# -----------------------------------------------------------------------------
$script:JsonPath = Join-Path $PSScriptRoot 'devices.json'
$PingCount       = 3   # multi-ping threshold

if (-not (Test-Path $JsonPath)) { '[]' | Set-Content $JsonPath -Encoding UTF8 }

$loadedDevices = Get-Content $JsonPath -Raw | ConvertFrom-Json
# Ensure we always have an array, even if JSON has a single object
$script:devices = @($loadedDevices | ForEach-Object {
    $_ | Add-Member -NotePropertyName ConsecutiveFailures -NotePropertyValue 0 -Force
    $_ | Add-Member -NotePropertyName LastPingTime -NotePropertyValue '' -Force
    $_ | Add-Member -NotePropertyName LastPingDateTime -NotePropertyValue ([DateTime]::MinValue) -Force
    $_
})
if (-not $script:devices) { $script:devices = @() }

# -----------------------------------------------------------------------------
#   GUI – Windows Forms
# -----------------------------------------------------------------------------
$form = [System.Windows.Forms.Form]@{
    Text='Device Status Monitor'; Size=[Drawing.Size]::new(900,600);
    MinimumSize=[Drawing.Size]::new(860,560); StartPosition='CenterScreen';
    AutoScaleMode='Dpi'; Topmost=$true }

# Status bar for visual feedback
$statusBar = New-Object System.Windows.Forms.StatusStrip
$statusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$statusLabel.Text = 'Ready'
$statusLabel.Spring = $true
$statusBar.Items.Add($statusLabel) | Out-Null
$form.Controls.Add($statusBar)

# DataGridView -----------------------------------------------------------------
$dgv            = New-Object System.Windows.Forms.DataGridView
$dgv.Dock       = 'Fill'
$dgv.AllowUserToAddRows=$false; $dgv.RowHeadersVisible=$false; $dgv.SelectionMode='FullRowSelect'
$dgv.AutoSizeColumnsMode='Fill'
[void]$dgv.Columns.Add('Name','Name')
[void]$dgv.Columns.Add('Address','IP / Hostname')
[void]$dgv.Columns.Add('Ticket','Ticket')
$statusCol=$dgv.Columns.Add('Status','Status'); $dgv.Columns[$statusCol].ReadOnly=$true
$intervalCol=$dgv.Columns.Add('Interval','Interval (s)')
$lastPingTimeCol=$dgv.Columns.Add('LastPingTime','Last Ping Time'); $dgv.Columns[$lastPingTimeCol].ReadOnly=$true
$form.Controls.Add($dgv)

# Input panel ------------------------------------------------------------------
$panel      = New-Object System.Windows.Forms.Panel
$panel.Dock='Bottom'; $panel.Height=110; $panel.Padding='10,10,10,10'
$form.Controls.Add($panel)

$lblName  = [System.Windows.Forms.Label]@{Text='Name:';AutoSize=$true;Location=[Drawing.Point]::new(0,5)}
$txtName  = [System.Windows.Forms.TextBox]@{Location=[Drawing.Point]::new(50,2);Size=[Drawing.Size]::new(150,22)}

$lblIP    = [System.Windows.Forms.Label]@{Text='IP/Host (opt):';AutoSize=$true;Location=[Drawing.Point]::new(220,5)}
$txtIP    = [System.Windows.Forms.TextBox]@{Location=[Drawing.Point]::new(310,2);Size=[Drawing.Size]::new(150,22)}

$lblTicket = [System.Windows.Forms.Label]@{Text='Ticket:';AutoSize=$true;Location=[Drawing.Point]::new(480,5)}
$txtTicket = [System.Windows.Forms.TextBox]@{Location=[Drawing.Point]::new(530,2);Size=[Drawing.Size]::new(120,22)}

$btnAdd   = [System.Windows.Forms.Button]@{Text='Add';Location=[Drawing.Point]::new(660,0);Size=[Drawing.Size]::new(80,26)}

# Second row
$btnRemove   = [System.Windows.Forms.Button]@{Text='Remove Selected';Location=[Drawing.Point]::new(0,45);Size=[Drawing.Size]::new(130,26)}
$lblInterval = [System.Windows.Forms.Label]@{Text='Default Interval (s):';AutoSize=$true;Location=[Drawing.Point]::new(220,50)}
$numInterval = New-Object System.Windows.Forms.NumericUpDown
$numInterval.Location=[Drawing.Point]::new(350,45); $numInterval.Minimum=5; $numInterval.Maximum=900; $numInterval.Value=30; $numInterval.Width=70; $numInterval.Increment=5

$panel.Controls.AddRange(@($lblName,$txtName,$lblIP,$txtIP,$lblTicket,$txtTicket,$btnAdd,$btnRemove,$lblInterval,$numInterval))

# --------------------------- Helpers ------------------------------------------
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
            
            # Update form title with device count
            $form.Text = "Device Status Monitor - $($script:devices.Count) device(s)"
        } catch {
            $retryCount++
            if ($retryCount -lt $maxRetries) {
                Start-Sleep -Milliseconds 50
            }
        }
    }
}

function Show-Toast($deviceName, $address, $ticket) {
    $timestamp = Get-Date -Format 'HH:mm:ss'
    Write-Host "[$timestamp] TOAST TRIGGER: Device '$deviceName' ($address) back online" -ForegroundColor Green
    $statusLabel.Text = "🔔 [$timestamp] Toast: $deviceName back online!"
    
    try {
        if (-not (Get-Module -ListAvailable -Name BurntToast)) { 
            Write-Host "[$timestamp] BurntToast module not available - using system sound" -ForegroundColor Yellow
            $statusLabel.Text = "[$timestamp] BurntToast not installed - sound played for $deviceName"
            throw 'BurntToast missing' 
        }
        Import-Module BurntToast -ErrorAction Stop | Out-Null
        
        $title = 'Device Back Online'
        $line1 = "$deviceName ($address)"
        $line2 = if ($ticket) { "Ticket: $ticket" } else { "No ticket assigned" }
        
        New-BurntToastNotification -Text $title, $line1, $line2 -AppLogo "$env:SystemRoot\System32\imageres.dll,-196" | Out-Null
        Write-Host "[$timestamp] Toast notification sent successfully" -ForegroundColor Green
    } catch {
        Write-Host "[$timestamp] Toast failed, playing system sound: $_" -ForegroundColor Yellow
        $statusLabel.Text = "[$timestamp] Toast failed for $deviceName - sound played"
        [System.Media.SystemSounds]::Exclamation.Play()
    }
}

# --------------------------- Seed grid ----------------------------------------
foreach ($d in $devices) {
    $interval = if ($d.PSObject.Properties.Match('Interval').Count -eq 0) { $numInterval.Value } else { $d.Interval }
    $lastPingTime = if ($d.PSObject.Properties.Match('LastPingTime').Count -eq 0) { '' } else { $d.LastPingTime }
    $row=$dgv.Rows.Add($d.Name,$d.Address,$d.Ticket,$d.Status,$interval,$lastPingTime); $dgv.Rows[$row].Tag=$d.Status
}
$form.Text = "Device Status Monitor - $($script:devices.Count) device(s)"

# --------------------------- Add device ---------------------------------------
$btnAdd.Add_Click({
    $name=$txtName.Text.Trim(); if (-not $name) { return }
    $addr=$txtIP.Text.Trim(); if (-not $addr) { $addr=$name }
    $grp=$txtTicket.Text.Trim()
    $interval=$numInterval.Value

    $row=$dgv.Rows.Add($name,$addr,$grp,'Unknown',$interval,''); $dgv.Rows[$row].Tag='Unknown'
    $script:devices += [PSCustomObject]@{Name=$name;Address=$addr;Ticket=$grp;Status='Unknown';ConsecutiveFailures=0;Interval=$interval;LastPingTime='';LastPingDateTime=[DateTime]::MinValue}
    Save-Devices
    $txtName.Clear();$txtIP.Clear();$txtTicket.Clear()
})

# --------------------------- Remove device ------------------------------------
$btnRemove.Add_Click({
    foreach ($row in @($dgv.SelectedRows)) {
        $name=$row.Cells[0].Value; $dgv.Rows.Remove($row)
        $script:devices = $script:devices | Where-Object { $_.Name -ne $name }
    }
    Save-Devices
})

# --------------------------- Staggered ping with per-device intervals -----------
function Invoke-PingBatch([System.Collections.IList]$deviceRows) {
    # Only ping devices that are due based on their individual intervals
    $now = Get-Date
    $devicesToPing = @()
    $maxConcurrentPings = 5  # Limit concurrent pings to prevent UI freezing
    
    foreach ($row in $deviceRows) {
        $name = $row.Cells[0].Value
        $device = $script:devices | Where-Object Name -eq $name
        if (-not $device) { continue }
        
        # Check if this device is due for a ping based on its interval
        $interval = if ($row.Cells[$intervalCol].Value) { [int]$row.Cells[$intervalCol].Value } else { 30 }
        $timeSinceLastPing = ($now - $device.LastPingDateTime).TotalSeconds
        
        if ($timeSinceLastPing -ge $interval) {
            $devicesToPing += [PSCustomObject]@{Row=$row; Device=$device; Name=$name}
            if ($devicesToPing.Count -ge $maxConcurrentPings) { break }  # Limit per tick
        }
    }
    
    if ($devicesToPing.Count -eq 0) { return }  # Nothing to ping this tick
    
    # Ping script for PS 5.1 compatibility
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
    
    # Create runspace pool and launch pings
    $pool=[runspacefactory]::CreateRunspacePool(1,10); $pool.Open(); $jobs=@()
    foreach ($item in $devicesToPing) {
        $addr=$item.Row.Cells[1].Value; $ps=[powershell]::Create(); $ps.RunspacePool=$pool
        $null=$ps.AddScript($pingScript).AddArgument($addr)
        $jobs += [pscustomobject]@{Item=$item;PS=$ps;Handle=$ps.BeginInvoke()}
    }
    # Process results
    foreach ($j in $jobs) {
        $online=[bool]($j.PS.EndInvoke($j.Handle)); $j.PS.Dispose()
        $item = $j.Item
        $row = $item.Row
        $device = $item.Device
        $name = $item.Name
        
        # Update ping timestamp
        $device.LastPingDateTime = Get-Date
        
        if ($online){$device.ConsecutiveFailures=0;$status='Online'}else{$device.ConsecutiveFailures++; if($device.ConsecutiveFailures -ge $PingCount){$status='Offline'}else{$status='Online'}}
        $prev=$row.Tag; $row.Cells[3].Value=$status
        $row.Cells[3].Style.ForeColor= if($status -eq 'Online'){[Drawing.Color]::ForestGreen}elseif($status -eq 'Offline'){[Drawing.Color]::Red}else{[Drawing.Color]::Orange}
        $row.Tag=$status; $device.Status=$status
        $lastPingTime = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $row.Cells[$lastPingTimeCol].Value = $lastPingTime
        $device.LastPingTime = $lastPingTime
        $addr = $row.Cells[1].Value
        $ticket = $row.Cells[2].Value
        
        # Debug logging for status transitions
        $timestamp = Get-Date -Format 'HH:mm:ss'
        Write-Host "[$timestamp] ${name}: prev='$prev' -> status='$status' (CF=$($device.ConsecutiveFailures))" -ForegroundColor Cyan
        
        # Update status bar with ping results
        if ($prev -ne $status) {
            $statusLabel.Text = "[$timestamp] ${name}: $prev → $status"
        }
        
        if ($prev -eq 'Offline' -and $status -eq 'Online') { 
            Show-Toast $name $addr $ticket 
        }
    }
    $pool.Close();$pool.Dispose()
    
    # Only save if we actually pinged devices
    if ($jobs.Count -gt 0) { Save-Devices }
}

# --------------------------- Timer (fast tick for staggered pinging) ----------
$timer=New-Object System.Windows.Forms.Timer; $timer.Interval=5000  # Check every 5 seconds
$timer.Add_Tick({ Invoke-PingBatch $dgv.Rows }); $timer.Start()
$numInterval.Add_ValueChanged({
    foreach ($row in $dgv.Rows) {
        if ($row.Selected) {
            $row.Cells[$intervalCol].Value = $numInterval.Value
            $device = $script:devices | Where-Object { $_.Name -eq $row.Cells[0].Value }
            if ($device) {
                $device.Interval = $numInterval.Value
            }
        }
    }
    Save-Devices
})

# --------------------------- Interval Editing ---------------------------------
$dgv.Add_CellEndEdit({
    param ($sender, $e)
    if ($e.ColumnIndex -eq $intervalCol) {
        $row = $dgv.Rows[$e.RowIndex]
        $newInterval = [int]$row.Cells[$intervalCol].Value
        $device = $script:devices | Where-Object { $_.Name -eq $row.Cells[0].Value }
        if ($device) {
            $device.Interval = $newInterval
        }
        Save-Devices
    }
})

# --------------------------- Cleanup ------------------------------------------
$form.Add_FormClosing({ $timer.Stop(); Save-Devices })

[void]$form.ShowDialog()
