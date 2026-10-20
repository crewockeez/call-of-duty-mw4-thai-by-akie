param([string]$RuntimePath, [switch]$NonInteractive)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
[Console]::OutputEncoding = New-Object Text.UTF8Encoding($false)
$Bundle = Split-Path -Parent $PSScriptRoot
function Hash([string]$Path) {
    $s = [IO.File]::OpenRead($Path)
    $a = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($a.ComputeHash($s))).Replace('-','').ToLowerInvariant() }
    finally { $a.Dispose(); $s.Dispose() }
}
try {
    $meta = Get-Content -LiteralPath (Join-Path $Bundle 'project.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $target = Join-Path $Bundle 'runtime-local'
    $names = @('bink2w64.dll','trhook.dll')
    $ready = $true
    foreach ($name in $names) {
        $path = Join-Path $target $name
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { $ready = $false }
        elseif ((Hash $path) -ne $meta.runtime_hashes.$name) { $ready = $false }
    }
    if ($ready) { Write-Host 'Compatible local runtime already prepared.'; exit 0 }
    if (-not $RuntimePath) {
        if ($NonInteractive) { throw '-RuntimePath required when runtime-local is incomplete' }
        Add-Type -AssemblyName System.Windows.Forms
        $picker = New-Object Windows.Forms.FolderBrowserDialog
        $picker.Description = 'เลือกโฟลเดอร์ files ของ MW4-Farsi v1.3 ที่แตก ZIP แล้ว เพื่อนำเข้าตัวโหลดในเครื่อง (ไม่ใช้ตัวจัด RTL ของเปอร์เซีย)'
        $picker.ShowNewFolderButton = $false
        try {
            if ($picker.ShowDialog() -ne [Windows.Forms.DialogResult]::OK) { exit 2 }
            $RuntimePath = $picker.SelectedPath
        } finally { $picker.Dispose() }
    }
    $base = (Resolve-Path -LiteralPath $RuntimePath).ProviderPath
    $resolved = $null
    foreach ($candidate in @($base, (Join-Path $base 'files'), (Join-Path $base 'MW4-Farsi\files'))) {
        if ((Test-Path -LiteralPath (Join-Path $candidate 'bink2w64.dll') -PathType Leaf) -and (Test-Path -LiteralPath (Join-Path $candidate 'trhook.dll') -PathType Leaf)) { $resolved = $candidate; break }
    }
    if (-not $resolved) { throw 'ไม่พบ bink2w64.dll และ trhook.dll กรุณาเลือกโฟลเดอร์ files ของชุดที่รองรับ' }
    foreach ($name in $names) {
        if ((Hash (Join-Path $resolved $name)) -ne $meta.runtime_hashes.$name) { throw "ตัวโหลด $name ไม่ใช่รุ่นที่รองรับ ไม่มีการเปลี่ยนไฟล์เกม" }
    }
    if (-not (Test-Path -LiteralPath $target)) { $null = New-Item -ItemType Directory -Path $target }
    foreach ($name in $names) {
        Copy-Item -LiteralPath (Join-Path $resolved $name) -Destination (Join-Path $target $name) -Force
        if ((Hash (Join-Path $target $name)) -ne $meta.runtime_hashes.$name) { throw "นำเข้าไฟล์ไม่สำเร็จ: $name" }
    }
    Write-Host 'Prepared compatible runtime locally. No game files were changed.'
    exit 0
} catch {
    Write-Host $_.Exception.Message
    if (-not $NonInteractive) {
        Add-Type -AssemblyName System.Windows.Forms
        [Windows.Forms.MessageBox]::Show($_.Exception.Message, 'AKIE - เตรียมตัวโหลดไม่สำเร็จ') | Out-Null
    }
    exit 1
}
