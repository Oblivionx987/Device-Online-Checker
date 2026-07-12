# Quick test for BurntToast notification
Import-Module BurntToast

$title = '🟢 Device Back Online'
$line1 = "SNC12345 (10.1.2.3)"
$line2 = "Ticket: INC0123456"

New-BurntToastNotification -Text $title, $line1, $line2 -AppLogo "$env:SystemRoot\System32\imageres.dll"

Write-Host "Toast notification sent! Check your Action Center for the notification." -ForegroundColor Green
