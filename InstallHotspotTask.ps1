# InstallHotspotTask.ps1
# Run as Administrator - creates the keepalive script and sets everything up

# ── 1. Allow local scripts to run ────────────────────────────────────────────
Write-Host ""
Write-Host "[ 1/6 ] Setting execution policy..." -ForegroundColor Cyan
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
Write-Host "        Execution policy set to RemoteSigned." -ForegroundColor Green

# ── 2. Ask for hotspot name and password ─────────────────────────────────────
Write-Host ""
Write-Host "[ 2/6 ] Hotspot configuration..." -ForegroundColor Cyan

$hotspotName = Read-Host "        Enter hotspot name (SSID)"

do {
    $hotspotPass = Read-Host "        Enter hotspot password (min 8 characters)"
    if ($hotspotPass.Length -lt 8) {
        Write-Host "        Password must be at least 8 characters. Try again." -ForegroundColor Red
    }
} while ($hotspotPass.Length -lt 8)

Write-Host "        Hotspot name: $hotspotName" -ForegroundColor Green
Write-Host "        Password set successfully." -ForegroundColor Green

# ── 3. Create the keepalive script ───────────────────────────────────────────
Write-Host ""
Write-Host "[ 3/6 ] Creating HotspotKeepAlive.ps1 in C:\Scripts..." -ForegroundColor Cyan

New-Item -ItemType Directory -Force -Path "C:\Scripts" | Out-Null

$keepAliveScript = @"
# HotspotKeepAlive.ps1 - Auto-generated. Do not delete.
Add-Type -AssemblyName System.Runtime.WindowsRuntime

function Await(`$task) {
    `$task.GetAwaiter().GetResult()
}

[Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager, Windows.Networking.NetworkOperators, ContentType = WindowsRuntime] | Out-Null
[Windows.Networking.Connectivity.NetworkInformation, Windows.Networking.Connectivity, ContentType = WindowsRuntime] | Out-Null

function Set-HotspotConfig {
    try {
        `$connectionProfile = [Windows.Networking.Connectivity.NetworkInformation]::GetInternetConnectionProfile()
        if (`$null -eq `$connectionProfile) { return }
        `$manager = [Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager]::CreateFromConnectionProfile(`$connectionProfile)
        `$config = `$manager.GetCurrentAccessPointConfiguration()
        `$config.Ssid = "$hotspotName"
        `$config.Passphrase = "$hotspotPass"
        Await(`$manager.ConfigureAccessPointAsync(`$config))
    } catch {
        Write-Host "`$(Get-Date): Could not set hotspot config - `$_"
    }
}

function Get-TetheringManager {
    `$connectionProfile = [Windows.Networking.Connectivity.NetworkInformation]::GetInternetConnectionProfile()
    if (`$null -eq `$connectionProfile) { return `$null }
    return [Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager]::CreateFromConnectionProfile(`$connectionProfile)
}

function Enable-Hotspot {
    try {
        `$manager = Get-TetheringManager
        if (`$null -eq `$manager) {
            Write-Host "`$(Get-Date): No internet connection profile found. Retrying..."
            return
        }
        `$status = `$manager.TetheringOperationalState
        if (`$status -ne 1) {
            Write-Host "`$(Get-Date): Hotspot is OFF (state: `$status). Turning ON..."
            Await(`$manager.StartTetheringAsync())
            Write-Host "`$(Get-Date): Hotspot turned ON successfully."
        } else {
            Write-Host "`$(Get-Date): Hotspot is already ON."
        }
    } catch {
        Write-Host "`$(Get-Date): Error - `$_"
    }
}

Write-Host "HotspotKeepAlive started. SSID: $hotspotName | Checking every 30 seconds..."
Set-HotspotConfig

while (`$true) {
    Enable-Hotspot
    Start-Sleep -Seconds 30
}
"@

Set-Content -Path "C:\Scripts\HotspotKeepAlive.ps1" -Value $keepAliveScript -Encoding UTF8
Write-Host "        HotspotKeepAlive.ps1 created." -ForegroundColor Green

# ── 4. Register the scheduled task ───────────────────────────────────────────
Write-Host ""
Write-Host "[ 4/6 ] Registering scheduled task..." -ForegroundColor Cyan

$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"C:\Scripts\HotspotKeepAlive.ps1`""

$trigger = New-ScheduledTaskTrigger -AtStartup

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit 0 `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1)

$principal = New-ScheduledTaskPrincipal `
    -UserId "SYSTEM" `
    -LogonType ServiceAccount `
    -RunLevel Highest

Register-ScheduledTask `
    -TaskName "HotspotKeepAlive" `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Principal $principal `
    -Description "Keeps Windows Mobile Hotspot always enabled" `
    -Force | Out-Null

Write-Host "        Scheduled task registered." -ForegroundColor Green

# ── 5. Start the task immediately ────────────────────────────────────────────
Write-Host ""
Write-Host "[ 5/6 ] Starting task now..." -ForegroundColor Cyan
Start-ScheduledTask -TaskName "HotspotKeepAlive"
Start-Sleep -Seconds 2
Write-Host "        Task started." -ForegroundColor Green

# ── 6. Show current status ───────────────────────────────────────────────────
Write-Host ""
Write-Host "[ 6/6 ] Task status:" -ForegroundColor Cyan
$state = (Get-ScheduledTask -TaskName "HotspotKeepAlive").State

if ($state -eq "Running") {
    Write-Host "        HotspotKeepAlive is ACTIVE and running." -ForegroundColor Green
} else {
    Write-Host "        HotspotKeepAlive state: $state" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  Hotspot Name : $hotspotName" -ForegroundColor White
Write-Host "  Password     : $hotspotPass" -ForegroundColor White
Write-Host ""
Write-Host "All done! The hotspot will auto-enable on every boot." -ForegroundColor White
Write-Host ""
