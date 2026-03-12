# ============================================================
#  BOD Test Reboot Guard - LOCKDOWN SCRIPT
#  Run this ONCE as Administrator before starting your BOD test
# ============================================================

# --- Elevate to Admin if needed ---
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  BOD Test Reboot Guard - LOCKDOWN" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# --------------------------------------------------
# 1. PREVENT WINDOWS AUTO-REBOOT
# --------------------------------------------------
Write-Host "[1/7] Setting Windows Update active hours to max..." -ForegroundColor Yellow
$auPath = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
if (-not (Test-Path $auPath)) { New-Item -Path $auPath -Force | Out-Null }
Set-ItemProperty -Path $auPath -Name "ActiveHoursStart" -Value 5 -Type DWord
Set-ItemProperty -Path $auPath -Name "ActiveHoursEnd" -Value 2 -Type DWord
Write-Host "  Done." -ForegroundColor Green

Write-Host "[2/7] Disabling auto-restart after updates..." -ForegroundColor Yellow
$noAutoRestart = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
if (-not (Test-Path $noAutoRestart)) { New-Item -Path $noAutoRestart -Force | Out-Null }
Set-ItemProperty -Path $noAutoRestart -Name "NoAutoRebootWithLoggedOnUsers" -Value 1 -Type DWord
Set-ItemProperty -Path $noAutoRestart -Name "AUOptions" -Value 4 -Type DWord
Write-Host "  Done." -ForegroundColor Green

Write-Host "[3/7] Pausing Windows Updates for 7 days..." -ForegroundColor Yellow
$pauseDate = (Get-Date).AddDays(7).ToString("yyyy-MM-ddTHH:mm:ssZ")
Set-ItemProperty -Path $auPath -Name "PauseUpdatesExpiryTime" -Value $pauseDate
try {
    $wu = New-Object -ComObject Microsoft.Update.AutoUpdate
    $wu.Pause()
    Write-Host "  Done (COM + registry)." -ForegroundColor Green
} catch {
    Write-Host "  Done (registry only - COM method unavailable)." -ForegroundColor Green
}

Write-Host "[4/7] Disabling Windows Update reboot scheduled tasks..." -ForegroundColor Yellow
$tasks = @(
    "\Microsoft\Windows\UpdateOrchestrator\Reboot"
    "\Microsoft\Windows\UpdateOrchestrator\Reboot_AC"
    "\Microsoft\Windows\UpdateOrchestrator\Reboot_Battery"
)
foreach ($task in $tasks) {
    try {
        Disable-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue | Out-Null
        Write-Host "  Disabled: $task" -ForegroundColor Green
    } catch {
        Write-Host "  Not found (OK): $task" -ForegroundColor DarkGray
    }
}

# --------------------------------------------------
# 2. PREVENT SLEEP / HIBERNATE ON AC POWER
# --------------------------------------------------
Write-Host "[5/7] Disabling sleep and hibernate on AC power..." -ForegroundColor Yellow
powercfg /change standby-timeout-ac 0
powercfg /change hibernate-timeout-ac 0
powercfg /change monitor-timeout-ac 30
powercfg /h off 2>$null
Write-Host "  Done. (Screen dims after 30 min, but PC stays awake)" -ForegroundColor Green

# --------------------------------------------------
# 3. REGISTER STARTUP ALERT TASK
# --------------------------------------------------
Write-Host "[6/7] Creating startup email alert scheduled task..." -ForegroundColor Yellow

$alertScript = Join-Path $ScriptDir "3_ON_REBOOT_send_alert.ps1"

$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$alertScript`""
$trigger = New-ScheduledTaskTrigger -AtStartup
$trigger.Delay = "PT60S"
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

try {
    Unregister-ScheduledTask -TaskName "BOD_RebootAlert" -Confirm:$false -ErrorAction SilentlyContinue
} catch {}

Register-ScheduledTask -TaskName "BOD_RebootAlert" `
    -Action $action -Trigger $trigger -Settings $settings -Principal $principal `
    -Description "Sends email alert when computer reboots during BOD test" | Out-Null

Write-Host "  Done. Task 'BOD_RebootAlert' registered." -ForegroundColor Green

# --------------------------------------------------
# 4. SEND TEST EMAIL
# --------------------------------------------------
Write-Host "[7/7] Sending test email via Resend..." -ForegroundColor Yellow
Write-Host ""

. (Join-Path $ScriptDir "BOD_RebootGuard_CONFIG.ps1")

if ($RESEND_API_KEY -eq "CHANGE_ME") {
    Write-Host "  ERROR: You need to edit BOD_RebootGuard_CONFIG.ps1 first!" -ForegroundColor Red
    Write-Host "  Fill in your Resend API key and email addresses." -ForegroundColor Red
    Write-Host ""
    Write-Host "  After editing, run this script again." -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

$testBody = @"
<h2>BOD Reboot Guard is ACTIVE</h2>
<p>This is a test email confirming the reboot monitor is working.</p>
<table style='font-family:monospace; border-collapse:collapse;'>
<tr><td style='padding:4px 12px; color:#666;'>Test:</td><td style='padding:4px 12px;'><b>$BOD_TEST_NAME</b></td></tr>
<tr><td style='padding:4px 12px; color:#666;'>Computer:</td><td style='padding:4px 12px;'>$env:COMPUTERNAME</td></tr>
<tr><td style='padding:4px 12px; color:#666;'>Time:</td><td style='padding:4px 12px;'>$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</td></tr>
<tr><td style='padding:4px 12px; color:#666;'>Recipients:</td><td style='padding:4px 12px;'>$($EMAIL_TO -join ', ')</td></tr>
</table>
<p style='color:green; font-weight:bold;'>If you got this email, you're all set. Start your BOD test.</p>
<p style='color:#999; font-size:12px;'>You will receive another email ONLY if this machine reboots.</p>
"@

# Build JSON manually to ensure the "to" array is correct
$toArrayJson = "[" + (($EMAIL_TO | ForEach-Object { "`"$_`"" }) -join ",") + "]"
$jsonBody = @"
{
  "from": "$EMAIL_FROM",
  "to": $toArrayJson,
  "subject": "[BOD GUARD] Test - Reboot Monitoring Active for $BOD_TEST_NAME",
  "html": $($testBody | ConvertTo-Json)
}
"@

Write-Host "  Sending to: $($EMAIL_TO -join ', ')" -ForegroundColor DarkGray
Write-Host "  From: $EMAIL_FROM" -ForegroundColor DarkGray
Write-Host ""

$headers = @{
    "Authorization" = "Bearer $RESEND_API_KEY"
    "Content-Type"  = "application/json"
}

try {
    $response = Invoke-RestMethod -Uri "https://api.resend.com/emails" -Method Post -Headers $headers -Body $jsonBody
    Write-Host "  Test email sent! Check your inbox." -ForegroundColor Green
    Write-Host "  Resend ID: $($response.id)" -ForegroundColor DarkGray
} catch {
    Write-Host "  FAILED to send test email!" -ForegroundColor Red
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $errorBody = $reader.ReadToEnd()
        Write-Host "  Resend says: $errorBody" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "  Check your config file. Common issues:" -ForegroundColor Yellow
    Write-Host "    - API key must start with 're_'" -ForegroundColor Yellow
    Write-Host "    - EMAIL_FROM must be from a verified domain in Resend" -ForegroundColor Yellow
    Write-Host "    - Or use 'onboarding@resend.dev' as EMAIL_FROM for testing" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  LOCKDOWN COMPLETE" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Windows auto-reboot: DISABLED"
Write-Host "  Sleep on AC power:   DISABLED"
Write-Host "  Reboot email alert:  ARMED"
Write-Host "  Test email:          SENT"
Write-Host "  Recipients:          $($EMAIL_TO -join ', ')"
Write-Host ""
Write-Host "  Keep the laptop PLUGGED IN for the full 5-day test."
Write-Host "  Run  4_UNDO_lockdown.ps1  when your test is done."
Write-Host ""
Read-Host "Press Enter to close"
