# ============================================================
#  BOD Test Reboot Guard - UNDO / RESTORE NORMAL
#  Run as Administrator after your BOD test is done
# ============================================================

if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  BOD Test Reboot Guard - UNDO" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1/5] Restoring Windows Update auto-restart..." -ForegroundColor Yellow
$noAutoRestart = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
Remove-ItemProperty -Path $noAutoRestart -Name "NoAutoRebootWithLoggedOnUsers" -ErrorAction SilentlyContinue
Remove-ItemProperty -Path $noAutoRestart -Name "AUOptions" -ErrorAction SilentlyContinue
Write-Host "  Done." -ForegroundColor Green

Write-Host "[2/5] Unpausing Windows Updates..." -ForegroundColor Yellow
$auPath = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
Remove-ItemProperty -Path $auPath -Name "PauseUpdatesExpiryTime" -ErrorAction SilentlyContinue
try { $wu = New-Object -ComObject Microsoft.Update.AutoUpdate; $wu.Resume() } catch {}
Write-Host "  Done." -ForegroundColor Green

Write-Host "[3/5] Re-enabling Windows Update reboot tasks..." -ForegroundColor Yellow
$tasks = @("\Microsoft\Windows\UpdateOrchestrator\Reboot", "\Microsoft\Windows\UpdateOrchestrator\Reboot_AC", "\Microsoft\Windows\UpdateOrchestrator\Reboot_Battery")
foreach ($task in $tasks) {
    try { Enable-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue | Out-Null; Write-Host "  Enabled: $task" -ForegroundColor Green }
    catch { Write-Host "  Not found (OK): $task" -ForegroundColor DarkGray }
}

Write-Host "[4/5] Restoring default sleep settings..." -ForegroundColor Yellow
powercfg /change standby-timeout-ac 30
powercfg /change hibernate-timeout-ac 60
powercfg /h on 2>$null
Write-Host "  Done." -ForegroundColor Green

Write-Host "[5/5] Removing reboot alert scheduled task..." -ForegroundColor Yellow
try { Unregister-ScheduledTask -TaskName "BOD_RebootAlert" -Confirm:$false -ErrorAction SilentlyContinue; Write-Host "  Done." -ForegroundColor Green }
catch { Write-Host "  Task not found (already removed)." -ForegroundColor DarkGray }

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  LOCKDOWN REMOVED - Normal settings restored" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Read-Host "Press Enter to close"
