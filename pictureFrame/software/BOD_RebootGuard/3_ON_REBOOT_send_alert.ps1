# ============================================================
#  BOD Reboot Alert - Runs automatically on startup
#  DO NOT run manually (it's triggered by the scheduled task)
# ============================================================

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
. (Join-Path $ScriptDir "BOD_RebootGuard_CONFIG.ps1")

# Wait for network (up to 2 minutes)
$maxWait = 120
$waited = 0
while ($waited -lt $maxWait) {
    try {
        $null = Test-Connection -ComputerName "api.resend.com" -Count 1 -ErrorAction Stop
        break
    } catch {
        Start-Sleep -Seconds 5
        $waited += 5
    }
}

# Gather system info
$os = Get-CimInstance Win32_OperatingSystem
$bootTime = $os.LastBootUpTime
$now = Get-Date

# Check Windows Event Log for WHY it rebooted
$rebootReasons = @()
try {
    $events = Get-WinEvent -FilterHashtable @{
        LogName = 'System'
        Id = 1074, 6006, 6008, 41
        StartTime = $bootTime.AddMinutes(-5)
    } -MaxEvents 5 -ErrorAction SilentlyContinue

    foreach ($evt in $events) {
        $rebootReasons += "<li><b>Event $($evt.Id)</b> at $($evt.TimeCreated.ToString('HH:mm:ss')): $($evt.Message.Substring(0, [Math]::Min(200, $evt.Message.Length)))</li>"
    }
} catch {}

if ($rebootReasons.Count -eq 0) {
    $reasonHtml = "<p style='color:orange;'>No specific reboot reason found in Event Log. May have been a power loss or forced shutdown.</p>"
} else {
    $reasonHtml = "<ul>$($rebootReasons -join '')</ul>"
}

# Build email
$alertBody = @"
<h2 style='color:red;'>REBOOT DETECTED - BOD Test Machine</h2>
<p style='font-size:16px;'>The BOD test computer has rebooted. Your logging software may need to be restarted.</p>
<table style='font-family:monospace; border-collapse:collapse; margin:16px 0;'>
<tr><td style='padding:6px 16px; color:#666; border-bottom:1px solid #eee;'>Test:</td><td style='padding:6px 16px; border-bottom:1px solid #eee;'><b>$BOD_TEST_NAME</b></td></tr>
<tr><td style='padding:6px 16px; color:#666; border-bottom:1px solid #eee;'>Computer:</td><td style='padding:6px 16px; border-bottom:1px solid #eee;'>$env:COMPUTERNAME</td></tr>
<tr><td style='padding:6px 16px; color:#666; border-bottom:1px solid #eee;'>Boot time:</td><td style='padding:6px 16px; border-bottom:1px solid #eee;'><b>$($bootTime.ToString('yyyy-MM-dd HH:mm:ss'))</b></td></tr>
<tr><td style='padding:6px 16px; color:#666; border-bottom:1px solid #eee;'>Alert sent:</td><td style='padding:6px 16px; border-bottom:1px solid #eee;'>$($now.ToString('yyyy-MM-dd HH:mm:ss'))</td></tr>
<tr><td style='padding:6px 16px; color:#666;'>Network wait:</td><td style='padding:6px 16px;'>${waited}s</td></tr>
</table>

<h3>Probable Reboot Reason:</h3>
$reasonHtml

<h3 style='color:red;'>Action Required:</h3>
<ol>
<li>Check if your BOD logging software is still running</li>
<li>If not, restart it immediately to minimize data gaps</li>
<li>Note the gap time in your test log</li>
</ol>
"@

# Build JSON manually to ensure the "to" array is correct
$toArrayJson = "[" + (($EMAIL_TO | ForEach-Object { "`"$_`"" }) -join ",") + "]"
$jsonBody = @"
{
  "from": "$EMAIL_FROM",
  "to": $toArrayJson,
  "subject": "[BOD ALERT] REBOOT DETECTED - $BOD_TEST_NAME - $($bootTime.ToString('MMM dd HH:mm'))",
  "html": $($alertBody | ConvertTo-Json)
}
"@

$headers = @{
    "Authorization" = "Bearer $RESEND_API_KEY"
    "Content-Type"  = "application/json"
}

# Try sending up to 3 times
$sent = $false
for ($i = 0; $i -lt 3; $i++) {
    try {
        Invoke-RestMethod -Uri "https://api.resend.com/emails" -Method Post -Headers $headers -Body $jsonBody | Out-Null
        $sent = $true
        break
    } catch {
        Start-Sleep -Seconds 10
    }
}

# Log locally too
$logFile = Join-Path $ScriptDir "reboot_log.txt"
$logEntry = "$($now.ToString('yyyy-MM-dd HH:mm:ss')) | Boot: $($bootTime.ToString('yyyy-MM-dd HH:mm:ss')) | Email sent: $sent"
Add-Content -Path $logFile -Value $logEntry
