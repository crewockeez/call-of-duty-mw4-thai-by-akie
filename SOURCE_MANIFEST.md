# Source manifest

| Path | Purpose |
|---|---|
| `main.go` | Windows UI, UAC elevation, background worker, embedded hero artwork |
| `win32.go` | Minimal Win32 API bindings used by the UI |
| `installer.go` | Offline payload extraction, backup, install, uninstall, local state |
| `assets/hero.png` | Installer artwork |
| `assets/payload.zip` | Exact embedded mod payload |
| `PAYLOAD_SHA256.txt` | SHA-256 of the embedded payload archive |
| `PAYLOAD_CONTENT_SHA256.txt` | SHA-256 of every embedded payload file |
| `SECURITY.md` | Human-readable behavior/security disclosure |
| `build.ps1` / `build.bat` | Reproducible Windows build commands |
| `RELEASE_SHA256.txt` | SHA-256 of the SourceReview executable built from this tree |
