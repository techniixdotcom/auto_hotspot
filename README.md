# InstallHotspotTask.ps1

A PowerShell setup script that configures Windows Mobile Hotspot to turn on automatically at every boot and stay on — even if it gets switched off unexpectedly.

---

## What It Does

The script runs through 6 steps:

1. **Sets execution policy** — enables local scripts to run by setting `RemoteSigned` for the current user.
2. **Prompts for hotspot credentials** — asks for an SSID (network name) and a password (minimum 8 characters, validated interactively).
3. **Generates `HotspotKeepAlive.ps1`** — writes a self-contained keepalive script to `C:\Scripts\` that uses the Windows Runtime networking API to check the hotspot state every 30 seconds and re-enable it if it's found to be off.
4. **Registers a Scheduled Task** — creates a Windows Task Scheduler entry (`HotspotKeepAlive`) that runs the keepalive script at startup as the `SYSTEM` account with the highest privileges. The task runs indefinitely, restarts up to 3 times on failure (1-minute interval), and continues running on battery.
5. **Starts the task immediately** — kicks off the keepalive loop right away without requiring a reboot.
6. **Reports status** — confirms the task is running and displays the configured SSID and password.

---

## Requirements

- **Windows 10 or 11** with Mobile Hotspot capability
- **PowerShell 5.1+** (built into Windows)
- **Administrator privileges** — required to register the Scheduled Task under the `SYSTEM` account

---

## Usage

1. Right-click **PowerShell** and select **Run as Administrator**.
2. Navigate to the folder containing the script:
   ```powershell
   cd C:\path\to\script
   ```
3. Run the installer:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\InstallHotspotTask.ps1
   ```
4. Follow the prompts to enter your desired hotspot name and password.

That's it — the hotspot will now auto-enable on every boot.

---

## Files Created

| Path | Description |
|---|---|
| `C:\Scripts\HotspotKeepAlive.ps1` | The generated keepalive script (do not delete) |
| Task Scheduler → `HotspotKeepAlive` | The scheduled task that runs the keepalive at startup |

---

## Managing the Task

| Action | Command |
|---|---|
| Check task status | `Get-ScheduledTask -TaskName "HotspotKeepAlive"` |
| Stop the task | `Stop-ScheduledTask -TaskName "HotspotKeepAlive"` |
| Remove the task | `Unregister-ScheduledTask -TaskName "HotspotKeepAlive" -Confirm:$false` |

---

## Notes

- The generated `HotspotKeepAlive.ps1` has your SSID and password embedded in plain text. Keep `C:\Scripts\` access restricted if you're on a shared machine.
- The keepalive loop checks every **30 seconds**. There may be a brief window after boot before the hotspot is confirmed active.
- If no active internet connection profile is found at check time, the script logs a message and retries on the next cycle.
- Re-running `InstallHotspotTask.ps1` will overwrite the existing task and regenerate the keepalive script with new credentials.
