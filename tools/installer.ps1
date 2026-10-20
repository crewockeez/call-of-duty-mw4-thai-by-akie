param(
    [ValidateSet('install','uninstall','resize','update')][string]$Mode = 'install',
    [ValidateSet('normal','large','largest')][string]$SubtitleSize = 'large',
    [string]$GamePath,
    [switch]$NonInteractive
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$Bundle = Split-Path -Parent $PSScriptRoot
$MarkerName = 'mw4-thai-install.json'
$PayloadNames = @('bink2w64.dll','trhook.dll','rtlcompanion.dll','trdata2.bin')
$TurkishDxgiHash = '2B5CE122DCB7395F209125CBC6EAAC6297A999B657A5E14555D2D1645FF36FEF'
$Manifest = $null
$Sp26 = $null

function Resolve-Payload([string]$Name) {
    if ($Name -in @('bink2w64.dll','trhook.dll')) { return Join-Path (Join-Path $Bundle 'runtime-local') $Name }
    if ($Name -in @('rtlcompanion.dll','trdata2.bin')) { return Join-Path (Join-Path $Bundle 'files') $Name }
    throw 'Invalid payload filename'
}

function Get-Sha([string]$Path) {
    $stream = [System.IO.File]::OpenRead($Path)
    $algorithm = [System.Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($algorithm.ComputeHash($stream))).Replace('-', '').ToLowerInvariant() }
    finally { $algorithm.Dispose(); $stream.Dispose() }
}
function Notify([string]$Text, [bool]$Failed = $false) {
    Write-Host $Text
    if (-not $NonInteractive) {
        Add-Type -AssemblyName System.Windows.Forms
        $icon = [System.Windows.Forms.MessageBoxIcon]::Information
        if ($Failed) { $icon = [System.Windows.Forms.MessageBoxIcon]::Error }
        [System.Windows.Forms.MessageBox]::Show($Text, 'Call of Duty MW4 Thai by AKIE', [System.Windows.Forms.MessageBoxButtons]::OK, $icon) | Out-Null
    }
}
function Resolve-Game([string]$Path) {
    if (-not $Path) { throw 'ยังไม่ได้เลือกโฟลเดอร์เกม' }
    $resolved = (Resolve-Path -LiteralPath $Path).ProviderPath
    if (Test-Path -LiteralPath (Join-Path $resolved 'sp26-cod.exe') -PathType Leaf) { return $resolved }
    $child = Join-Path $resolved 'sp26'
    if (Test-Path -LiteralPath (Join-Path $child 'sp26-cod.exe') -PathType Leaf) { return $child }
    throw 'ไม่พบ sp26-cod.exe กรุณาเลือกโฟลเดอร์หลักของเกม หรือโฟลเดอร์ sp26'
}
function Resolve-Target([string]$Id) {
    foreach ($name in $PayloadNames) {
        if ($Id -ceq ('sp26/' + $name)) { return Join-Path $Sp26 $name }
        if ($Id -ceq ('root/' + $name)) { return Join-Path (Split-Path -Parent $Sp26) $name }
    }
    if ($Id -ceq 'sp26/dxgi.dll') { return Join-Path $Sp26 'dxgi.dll' }
    if ($Id -ceq 'root/dxgi.dll') { return Join-Path (Split-Path -Parent $Sp26) 'dxgi.dll' }
    throw "Invalid tracked file: $Id"
}
function Resolve-Backup([object]$State) {
    if ($State.Schema -ne 1 -or $State.BackupDir -notmatch '^\d{8}-\d{6}-[a-f0-9]{32}$') {
        throw 'รูปแบบข้อมูลสำรองไม่ถูกต้อง จึงหยุดเพื่อรักษาไฟล์เดิม'
    }
    return Join-Path (Join-Path $Sp26 '.mw4-thai-backups') $State.BackupDir
}
function Check-State([object]$State, [bool]$CheckInstalled) {
    $backup = Resolve-Backup $State
    $seen = @{}
    if (@($State.Entries).Count -notin @(4,5,6,8,9,10)) { throw 'Invalid backup file count' }
    foreach ($entry in $State.Entries) {
        $target = Resolve-Target $entry.Id
        if ($seen.ContainsKey($entry.Id)) { throw 'Duplicate backup entry' }
        $seen[$entry.Id] = $true
        if ($entry.BackupName -notmatch '^\d+\.bak$') { throw 'Invalid backup filename' }
        if ($entry.OriginalExists) {
            $original = Join-Path $backup $entry.BackupName
            if (-not (Test-Path -LiteralPath $original -PathType Leaf)) { throw "ไม่พบไฟล์สำรอง: $original" }
            if ((Get-Sha $original) -ne $entry.OriginalHash) { throw "ไฟล์สำรองเปลี่ยนแปลง: $original" }
        }
        if ($CheckInstalled -and (Test-Path -LiteralPath $target)) {
            if (-not $entry.InstalledHash -or (Get-Sha $target) -ne $entry.InstalledHash) {
                throw "ไฟล์เกมเปลี่ยนหลังติดตั้งม็อด: $target`nหยุดเพื่อไม่เขียนทับไฟล์จากอัปเดตหรือม็อดอื่น ข้อมูลสำรองอยู่ที่ $backup"
            }
        }
    }
    foreach ($name in $PayloadNames) {
        if (-not $seen.ContainsKey('sp26/' + $name)) { throw 'Incomplete installation manifest' }
        if ($State.PSObject.Properties['Layout'] -and $State.Layout -eq 'root-and-sp26-v1') {
            if (-not $seen.ContainsKey('root/' + $name)) { throw 'Incomplete mirrored installation manifest' }
        }
    }
    return $backup
}

try {
    if (-not $GamePath) {
        if ($NonInteractive) { throw '-GamePath is required with -NonInteractive' }
        Add-Type -AssemblyName System.Windows.Forms
        $picker = New-Object System.Windows.Forms.FolderBrowserDialog
        $picker.Description = 'เลือกโฟลเดอร์หลักของ Modern Warfare 4 หรือโฟลเดอร์ sp26'
        $picker.ShowNewFolderButton = $false
        try {
            if ($picker.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { exit 0 }
            $GamePath = $picker.SelectedPath
        } finally { $picker.Dispose() }
    }
    $Sp26 = Resolve-Game $GamePath
    if ((Split-Path -Leaf $Sp26) -ine 'sp26') { throw 'แพ็กนี้รองรับโครงสร้างโฟลเดอร์หลัก\sp26 กรุณาเลือกโฟลเดอร์ sp26 ที่อยู่ในโฟลเดอร์เกม' }
    if (Get-Process -Name 'sp26-cod','cod' -ErrorAction SilentlyContinue) { throw 'กรุณาปิดเกมก่อนติดตั้งหรือถอนม็อด' }
    $marker = Join-Path $Sp26 $MarkerName
    if ($Mode -in @('resize','update')) {
        if (-not (Test-Path -LiteralPath $marker -PathType Leaf)) { throw 'ไม่พบข้อมูลติดตั้งแพ็กเดิม กรุณาใช้ install.bat ก่อน' }
        $package = Get-Content -LiteralPath (Join-Path $Bundle 'package.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        $Manifest = Get-Content -LiteralPath $marker -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($Mode -eq 'resize' -and $Manifest.Version -ne $package.Version) { throw 'เวอร์ชันแพ็กไม่ตรงกับแพ็กที่ติดตั้งไว้' }
        if ($Mode -eq 'update') {
            if (-not $Manifest.PSObject.Properties['Layout'] -or $Manifest.Layout -ne 'root-and-sp26-v1') { throw 'แพ็กเดิมใช้โครงสร้างติดตั้งต่างกัน กรุณาถอนแพ็กเดิมแล้วใช้ install.bat' }
            if ($Manifest.Version -notin @($package.Version,'3.1-dev','4.0-dev')) { throw 'เวอร์ชันแพ็กเดิมยังไม่รองรับการอัปเดตโดยตรง กรุณาถอนแล้วติดตั้งใหม่' }
            foreach ($entry in $Manifest.Entries) {
                if ($entry.Id -notmatch '/trdata2\.bin$' -and $entry.InstalledHash) {
                    $name = Split-Path -Leaf (Resolve-Target $entry.Id)
                    if ($entry.InstalledHash -ne $package.Payload.$name) { throw 'ตัวโหลดเปลี่ยนเวอร์ชัน กรุณาถอนแพ็กเดิมแล้วติดตั้งใหม่' }
                }
            }
            $SubtitleSize = 'large'
            if ($Manifest.PSObject.Properties['SubtitleSize'] -and $Manifest.SubtitleSize -in @('normal','large','largest')) { $SubtitleSize = $Manifest.SubtitleSize }
        }
        $null = Check-State $Manifest $true
        $src = Join-Path (Join-Path $Bundle 'files') ('trdata2-' + $SubtitleSize + '.bin')
        $expected = $package.Variants.$SubtitleSize
        if (-not $expected -or (Get-Sha $src) -ne $expected) { throw 'ไฟล์ขนาดซับไม่ตรงกับแพ็ก กรุณาแตก ZIP ใหม่' }
        $snapshots = @()
        foreach ($entry in $Manifest.Entries) {
            if ($entry.Id -in @('sp26/trdata2.bin','root/trdata2.bin')) {
                $dst = Resolve-Target $entry.Id
                if (-not (Test-Path -LiteralPath $dst -PathType Leaf)) { throw "ไม่พบไฟล์ซับที่ติดตั้งไว้: $dst" }
                $snapshots += [pscustomobject]@{ Path = $dst; Data = [IO.File]::ReadAllBytes($dst) }
            }
        }
        $oldMarker = [IO.File]::ReadAllBytes($marker)
        try {
            foreach ($snapshot in $snapshots) {
                Copy-Item -LiteralPath $src -Destination $snapshot.Path -Force
                if ((Get-Sha $snapshot.Path) -ne $expected) { throw 'เขียนไฟล์ขนาดซับไม่สำเร็จ' }
            }
            foreach ($entry in $Manifest.Entries) {
                if ($entry.Id -in @('sp26/trdata2.bin','root/trdata2.bin')) { $entry.InstalledHash = $expected }
            }
            $Manifest | Add-Member -NotePropertyName SubtitleSize -NotePropertyValue $SubtitleSize -Force
            $Manifest.Version = $package.Version
            $Manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $marker -Encoding UTF8
        } catch {
            $failure = $_
            foreach ($snapshot in $snapshots) { [IO.File]::WriteAllBytes($snapshot.Path, $snapshot.Data) }
            [IO.File]::WriteAllBytes($marker, $oldMarker)
            throw "เปลี่ยนขนาดซับไม่สำเร็จ คืนไฟล์ก่อนเปลี่ยนแล้ว: $($failure.Exception.Message)"
        }
        Notify "อัปเดตข้อมูลซับแล้ว ($($package.Version), $SubtitleSize)`nเปิดเกมใหม่เพื่อทดสอบ`nข้อมูลสำรองเดิมยังใช้ถอนได้ตามปกติ"
        exit 0
    }
    if ($Mode -eq 'install') {
        $package = Get-Content -LiteralPath (Join-Path $Bundle 'package.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($package.Schema -ne 1) { throw 'Unsupported package manifest' }
        foreach ($name in $PayloadNames) {
            $src = Resolve-Payload $name
            $expected = $package.Payload.$name
            if (-not $expected -or (Get-Sha $src) -ne $expected) { throw "ไฟล์แพ็กไม่ครบหรือเปลี่ยนแปลง: $name`nกรุณาแตก ZIP ใหม่ทั้งโฟลเดอร์" }
        }
        if (Test-Path -LiteralPath $marker) {
            $Manifest = Get-Content -LiteralPath $marker -Raw -Encoding UTF8 | ConvertFrom-Json
            $null = Check-State $Manifest $true
            $same = $Manifest.Version -eq $package.Version
            foreach ($name in $PayloadNames) {
                $dst = Join-Path $Sp26 $name
                if (-not (Test-Path -LiteralPath $dst -PathType Leaf)) { $same = $false }
                elseif ((Get-Sha $dst) -ne $package.Payload.$name) { $same = $false }
                $rootDst = Resolve-Target ('root/' + $name)
                if (-not (Test-Path -LiteralPath $rootDst -PathType Leaf)) { $same = $false }
                elseif ((Get-Sha $rootDst) -ne $package.Payload.$name) { $same = $false }
            }
            if ($same) { Notify 'ติดตั้งเวอร์ชันนี้ไว้อยู่แล้ว ไฟล์ครบและตรงกับแพ็ก'; exit 0 }
            throw 'พบม็อดไทยที่ติดตั้งไว้ กรุณาใช้ uninstall.bat ของแพ็กเดิมก่อนติดตั้งเวอร์ชันนี้'
        }
        $backupId = (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N')
        $backup = Join-Path (Join-Path $Sp26 '.mw4-thai-backups') $backupId
        $null = New-Item -ItemType Directory -Path $backup
        $entries = @()
        foreach ($name in $PayloadNames) {
            $entries += [pscustomobject]@{ Id = 'sp26/' + $name; BackupName = ''; OriginalExists = $false; OriginalHash = $null; InstalledHash = $package.Payload.$name }
            $entries += [pscustomobject]@{ Id = 'root/' + $name; BackupName = ''; OriginalExists = $false; OriginalHash = $null; InstalledHash = $package.Payload.$name }
        }
        foreach ($id in @('sp26/dxgi.dll','root/dxgi.dll')) {
            $dst = Resolve-Target $id
            if ((Test-Path -LiteralPath $dst -PathType Leaf) -and (Get-Sha $dst) -eq $TurkishDxgiHash.ToLowerInvariant()) {
                $entries += [pscustomobject]@{ Id = $id; BackupName = ''; OriginalExists = $false; OriginalHash = $null; InstalledHash = $null }
            }
        }
        for ($i = 0; $i -lt $entries.Count; $i++) {
            $entry = $entries[$i]
            $entry.BackupName = "$i.bak"
            $dst = Resolve-Target $entry.Id
            if (Test-Path -LiteralPath $dst) {
                if (-not (Test-Path -LiteralPath $dst -PathType Leaf)) { throw "ปลายทางไม่ใช่ไฟล์: $dst" }
                $entry.OriginalExists = $true
                $entry.OriginalHash = Get-Sha $dst
                $saved = Join-Path $backup $entry.BackupName
                Copy-Item -LiteralPath $dst -Destination $saved
                if ((Get-Sha $saved) -ne $entry.OriginalHash) { throw "สำรองไฟล์ไม่สำเร็จ: $dst" }
            }
        }
        $Manifest = [pscustomobject]@{ Schema = 1; Version = $package.Version; Layout = 'root-and-sp26-v1'; BackupDir = $backupId; InstalledAt = [DateTime]::UtcNow.ToString('o'); Entries = $entries }
        # Recovery manifest is committed before changing any game file.
        $Manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $backup 'manifest.json') -Encoding UTF8
        $touched = @()
        try {
            foreach ($entry in $entries) {
                $dst = Resolve-Target $entry.Id
                $touched += $entry
                if ($entry.InstalledHash) {
                    $src = Resolve-Payload (Split-Path -Leaf $dst)
                    Copy-Item -LiteralPath $src -Destination $dst -Force
                    if ((Get-Sha $dst) -ne $entry.InstalledHash) { throw "เขียนไฟล์ไม่สำเร็จ: $dst" }
                } else { Remove-Item -LiteralPath $dst -Force }
            }
            $Manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $marker -Encoding UTF8
        } catch {
            $failure = $_
            $rollbackErrors = @()
            foreach ($entry in $touched) {
                try {
                    $dst = Resolve-Target $entry.Id
                    if ($entry.OriginalExists) { Copy-Item -LiteralPath (Join-Path $backup $entry.BackupName) -Destination $dst -Force }
                    elseif (Test-Path -LiteralPath $dst) { Remove-Item -LiteralPath $dst -Force }
                } catch { $rollbackErrors += $_.Exception.Message }
            }
            if ($rollbackErrors.Count -eq 0) {
                if (Test-Path -LiteralPath $marker) { Remove-Item -LiteralPath $marker -Force }
                throw "ติดตั้งไม่สำเร็จ คืนไฟล์ก่อนติดตั้งแล้ว: $($failure.Exception.Message)"
            }
            throw "ติดตั้งไม่สำเร็จ และคืนไฟล์ได้ไม่ครบ`n$($rollbackErrors -join [Environment]::NewLine)`nข้อมูลกู้คืน: $backup"
        }
        Notify "ติดตั้งแพ็กพัฒนาซับไทยแล้ว ($($package.Version))`n`nเลือกภาษา English และเปิด Subtitles`nทดสอบเฉพาะ Campaign/Offline`nแพ็กนี้ยังไม่ยืนยันครบแคมเปญ 100%`n`nไฟล์สำรอง: $backup`nถอนและคืนไฟล์ด้วย uninstall.bat"
    } else {
        if (-not (Test-Path -LiteralPath $marker -PathType Leaf)) { throw 'ไม่พบข้อมูลติดตั้งของแพ็กนี้ จึงไม่ได้ลบหรือเปลี่ยนไฟล์เกม' }
        $Manifest = Get-Content -LiteralPath $marker -Raw -Encoding UTF8 | ConvertFrom-Json
        $backup = Check-State $Manifest $true
        $stage = Join-Path $backup ('uninstall-' + [guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Path $stage
        $snapshots = @()
        foreach ($entry in $Manifest.Entries) {
            $dst = Resolve-Target $entry.Id
            $exists = Test-Path -LiteralPath $dst -PathType Leaf
            $snapshots += [pscustomobject]@{ Entry = $entry; Existed = $exists }
            if ($exists) {
                $saved = Join-Path $stage $entry.BackupName
                Copy-Item -LiteralPath $dst -Destination $saved
                if ((Get-Sha $saved) -ne (Get-Sha $dst)) { throw "สำรองสถานะก่อนถอนไม่สำเร็จ: $dst" }
            }
        }
        $touched = @()
        try {
            foreach ($snapshot in $snapshots) {
                $touched += $snapshot
                $entry = $snapshot.Entry
                $dst = Resolve-Target $entry.Id
                if ($entry.OriginalExists) {
                    Copy-Item -LiteralPath (Join-Path $backup $entry.BackupName) -Destination $dst -Force
                    if ((Get-Sha $dst) -ne $entry.OriginalHash) { throw "คืนไฟล์ไม่สำเร็จ: $dst" }
                } elseif (Test-Path -LiteralPath $dst) { Remove-Item -LiteralPath $dst -Force }
            }
            Remove-Item -LiteralPath $marker -Force
        } catch {
            $failure = $_
            $rollbackErrors = @()
            foreach ($snapshot in $touched) {
                try {
                    $dst = Resolve-Target $snapshot.Entry.Id
                    if ($snapshot.Existed) { Copy-Item -LiteralPath (Join-Path $stage $snapshot.Entry.BackupName) -Destination $dst -Force }
                    elseif (Test-Path -LiteralPath $dst) { Remove-Item -LiteralPath $dst -Force }
                } catch { $rollbackErrors += $_.Exception.Message }
            }
            throw "ถอนไม่สำเร็จ: $($failure.Exception.Message)`n$($rollbackErrors -join [Environment]::NewLine)`nข้อมูลกู้คืน: $backup"
        }
        Notify "ถอนม็อดและคืนไฟล์ที่มีอยู่ก่อนติดตั้งแล้ว`nเก็บข้อมูลสำรองไว้ที่ $backup"
    }
    exit 0
} catch {
    Notify $_.Exception.Message $true
    exit 1
}
