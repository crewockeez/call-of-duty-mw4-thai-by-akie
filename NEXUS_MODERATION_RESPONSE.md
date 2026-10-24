# Nexus Mods moderation response template

Send the repository URL privately to `support@nexusmods.com` as requested by the moderator.
Do not use the repository as an alternate public download link while the Nexus file is quarantined.

## Suggested subject

`Source code for review — MW4 Thai Localization Mod by akiemod`

## Suggested message

Hello Nexus Mods Support,

I received the moderation notice stating that my mod was considered to be bypassing quarantine through off-site download links. I understand the concern and I have removed / will remove any off-site download links that could be used to bypass the Nexus quarantine process.

As requested, here is the version-control repository containing the complete source code for the Windows installer used by my mod:

`<INSERT GITHUB REPOSITORY URL HERE>`

The repository also includes build instructions, the embedded payload manifest and SHA-256 hashes, and a security note describing exactly which files the installer reads/writes.

Important points for review:
- The installer is fully offline.
- It performs no HTTP/HTTPS requests and downloads nothing from external services.
- It does not launch PowerShell, CMD, BAT, WScript, or another downloader.
- The payload is embedded in the executable at build time.
- It only modifies the selected game's `sp26` folder, makes local backups, and supports uninstall/restore.
- Diagnostic logging is written only to the local TEMP directory.

I am happy to make any additional changes required by the moderation team. I will wait for your review before using any external links for distribution.

Thank you,
akiemod
