# MW4 Thai Campaign Installer — by akiemod

Source code for the Windows installer used by **MW4 Thai Localization Mod**.
This repository is provided for Nexus Mods moderation/security review and for reproducible inspection of the installer behavior.

## Important moderation disclosure

The installer is **fully offline**. It does not bypass Nexus quarantine and does not download files from GitHub, Google Drive, Discord, or any other external service. All files required by the installer are embedded in the executable at build time from `assets/payload.zip`.

See [`SECURITY.md`](SECURITY.md) for the complete list of file-system actions.
[`ดูหนัง`](https://tidnung.com) 

## Build requirements

- Windows 10/11
- Go 1.23.2 (recommended for hash-identical review builds)

No third-party Go modules are required; the project uses only the Go standard library and Windows APIs. Build scripts use `-trimpath -buildvcs=false` to keep review builds deterministic.

### Build

PowerShell:

```powershell
./build.ps1
```

or Command Prompt:

```bat
build.bat
```

Output:

`dist/MW4_Thai_Campaign_Setup_by_akiemod_SourceReview.exe`

## Embedded assets

- `assets/hero.png` — installer UI artwork.
- `assets/payload.zip` — exact mod payload embedded into the installer.

The payload contains only:

- `bink2w64.dll`
- `rtlcompanion.dll`
- `trhook.dll`
- `trdata2-normal.bin`
- `trdata2-large.bin`
- `trdata2-largest.bin`

## Installation behavior

The user selects the game folder or `sp26` folder. The installer validates `sp26-cod.exe`, creates a backup of existing target files, then installs the embedded payload. Subtitle size changes only which `trdata2-*.bin` is copied to `trdata2.bin`.

## Uninstall behavior

The installer restores original files from a backup and removes mod-only files where no original existed.

## Network behavior

None. This project does not import or use Go networking packages and contains no URL/download code.

## Nexus Mods review

This repository/source package is intended to be sent to Nexus Mods support in response to a moderator request for installer source code. The Nexus-hosted mod page should not contain off-site download links intended to bypass quarantine while the review is pending.
