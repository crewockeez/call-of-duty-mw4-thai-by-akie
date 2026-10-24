# Security / moderation notes

This installer is intentionally offline and contains no network client code.

## What the executable does
- Shows a Windows installer UI branded `by akiemod`.
- Lets the user select the game `sp26` directory (or its parent).
- Validates that `sp26-cod.exe` exists.
- Requests Administrator permission through the standard Windows UAC `runas` verb when required.
- Backs up existing target files before changing them.
- Writes only these mod targets inside the selected `sp26` directory:
  - `bink2w64.dll`
  - `rtlcompanion.dll`
  - `trhook.dll`
  - `trdata2.bin`
- Stores backups in `.thai-campaign-v3-backup` and recognizes the legacy backup folders `.thai-story-full-backup` and `.thai-demo-backup` for compatibility.
- Stores the last selected path in `%LOCALAPPDATA%\akiemod\MW4Thai\last_sp26.txt`.
- Writes a diagnostic log to `%TEMP%\MW4_Thai_Setup_by_akiemod.log`.
- Uninstall restores backed-up originals and removes mod-only files when no original existed.

## What it does NOT do
- No HTTP/HTTPS requests.
- No off-site downloads.
- No telemetry or analytics.
- No registry persistence, services, scheduled tasks, drivers, or startup entries.
- No PowerShell, CMD, BAT, WScript, or external downloader is launched by the installer.
- No process injection or game process modification is performed by the installer itself.

The embedded payload is `assets/payload.zip`. Its SHA-256 is listed in `PAYLOAD_SHA256.txt`.
