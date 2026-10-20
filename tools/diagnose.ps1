param([string]$GamePath, [switch]$NonInteractive)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$Bundle = Split-Path -Parent $PSScriptRoot

function Get-Sha([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $alg = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($alg.ComputeHash($stream))).Replace('-','').ToLowerInvariant() }
    finally { $alg.Dispose(); $stream.Dispose() }
}
function Check-Table([string]$Path, [object[]]$Cases) {
    $stream = $null
    $reader = $null
    try {
        $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
        $reader = [IO.BinaryReader]::new($stream)
        $utf8 = [Text.UTF8Encoding]::new($false, $true)
        $count = $reader.ReadUInt32()
        if ($count -gt 200000 -or $count -gt (($stream.Length - 4) / 4)) { throw 'Invalid table count' }
        $table = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
        for ($i = 0; $i -lt $count; $i++) {
            $pair = @()
            for ($j = 0; $j -lt 2; $j++) {
                $length = $reader.ReadUInt16()
                $bytes = $reader.ReadBytes($length)
                if ($bytes.Length -ne $length) { throw 'Truncated text' }
                $pair += $utf8.GetString($bytes)
            }
            if ($table.ContainsKey($pair[0])) { throw 'Duplicate table key' }
            $table.Add($pair[0], $pair[1])
        }
        if ($stream.Position -ne $stream.Length) { throw 'Trailing bytes' }
        $probes = @()
        foreach ($case in $Cases) {
            $present = $table.ContainsKey([string]$case.en)
            $actual = $null
            if ($present) { $actual = $table[[string]$case.en] -replace '^\^H\d+\^','' }
            $probes += [pscustomobject]@{ English = $case.en; KeyPresent = $present; ActualThai = $actual; ExpectedThai = $case.expected_th; MatchesExpected = $present -and ($actual -ceq $case.expected_th) }
        }
        return [pscustomobject]@{ Path = $Path; EntryCount = $count; ValidBinary = $true; Probes = $probes }
    } catch { return [pscustomobject]@{ Path = $Path; ValidBinary = $false; Error = $_.Exception.Message } }
    finally { if ($reader) { $reader.Dispose() } elseif ($stream) { $stream.Dispose() } }
}

try {
    if (-not $GamePath) {
        if ($NonInteractive) { throw '-GamePath required' }
        Add-Type -AssemblyName System.Windows.Forms
        $picker = New-Object System.Windows.Forms.FolderBrowserDialog
        $picker.Description = 'เลือกโฟลเดอร์เกมที่ใช้เล่นจริง หรือโฟลเดอร์ sp26 เพื่อตรวจไฟล์ซับ'
        $picker.ShowNewFolderButton = $false
        try {
            if ($picker.ShowDialog() -ne [Windows.Forms.DialogResult]::OK) { exit 0 }
            $GamePath = $picker.SelectedPath
        } finally { $picker.Dispose() }
    }
    $sp26 = (Resolve-Path -LiteralPath $GamePath).ProviderPath
    if (-not (Test-Path -LiteralPath (Join-Path $sp26 'sp26-cod.exe') -PathType Leaf)) { $sp26 = Join-Path $sp26 'sp26' }
    $exe = Join-Path $sp26 'sp26-cod.exe'
    if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) { throw 'ไม่พบ sp26-cod.exe ในโฟลเดอร์ที่เลือก' }
    $gameRoot = Split-Path -Parent $sp26
    $package = Get-Content -LiteralPath (Join-Path $Bundle 'package.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $cases = (Get-Content -LiteralPath (Join-Path $Bundle 'reports\visible_checks.json') -Raw -Encoding UTF8 | ConvertFrom-Json).cases
    $files = @()
    $tables = @()
    $locations = @(
        'sp26/bink2w64.dll','sp26/trhook.dll','sp26/rtlcompanion.dll','sp26/trdata2.bin','sp26/dxgi.dll',
        'bink2w64.dll','trhook.dll','rtlcompanion.dll','trdata2.bin','dxgi.dll','TurkceYama/sp26/trdata2.bin',
        'sp26/localization/tr_strings.tsv','localization/tr_strings.tsv'
    )
    foreach ($relative in $locations) {
        $path = Join-Path $gameRoot ($relative.Replace('/','\'))
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
        $hash = Get-Sha $path
        $expected = $null
        $match = $null
        if ($relative -match '^(?:sp26/)?([^/]+)$') {
            $prop = $package.Payload.PSObject.Properties[$Matches[1]]
            if ($prop) { $expected = $prop.Value; $match = $expected -eq $hash }
        }
        $knownBuild = @()
        if ($relative.EndsWith('trdata2.bin')) {
            foreach ($prop in $package.KnownDataBuilds.PSObject.Properties) { if ($prop.Value -eq $hash) { $knownBuild += $prop.Name } }
            foreach ($prop in $package.Variants.PSObject.Properties) { if ($prop.Value -eq $hash) { $knownBuild += ($package.Version + '-' + $prop.Name) } }
            if ($relative -in @('sp26/trdata2.bin','trdata2.bin') -and @($package.Variants.PSObject.Properties | Where-Object { $_.Value -eq $hash }).Count -gt 0) { $match = $true }
            $tables += Check-Table $path $cases
        }
        $files += [pscustomobject]@{ RelativePath = $relative; Bytes = (Get-Item -LiteralPath $path).Length; SHA256 = $hash; ExpectedHash = $expected; MatchesBundle = $match; KnownDataBuild = $knownBuild }
    }
    $processes = @()
    foreach ($proc in @(Get-Process -Name 'sp26-cod' -ErrorAction SilentlyContinue)) {
        $record = [ordered]@{ Id = $proc.Id; ExePath = $null; IsSelectedGame = $null; Modules = @(); ModuleReadError = $null }
        try {
            $record.ExePath = $proc.Path
            $record.IsSelectedGame = [string]::Equals($proc.Path, $exe, [StringComparison]::OrdinalIgnoreCase)
            foreach ($module in $proc.Modules) {
                if ($module.ModuleName -in @('bink2w64.dll','trhook.dll','rtlcompanion.dll','dxgi.dll')) {
                    $record.Modules += [pscustomobject]@{ Name = $module.ModuleName; Path = $module.FileName }
                }
            }
        } catch { $record.ModuleReadError = $_.Exception.Message }
        $processes += [pscustomobject]$record
    }
    $logs = @()
    foreach ($relative in @('sp26/trhook.log','sp26/tr_hook.log','trhook.log','tr_hook.log','sp26/localization/untranslated_live.txt','localization/untranslated_live.txt')) {
        $path = Join-Path $gameRoot ($relative.Replace('/','\'))
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            try { $logs += [pscustomobject]@{ RelativePath = $relative; Tail = @(Get-Content -LiteralPath $path -Tail 100 -Encoding UTF8) } }
            catch { $logs += [pscustomobject]@{ RelativePath = $relative; Error = $_.Exception.Message } }
        }
    }
    $report = [ordered]@{
        BundleVersion = $package.Version; SelectedSp26 = $sp26;
        GameFileVersion = [Diagnostics.FileVersionInfo]::GetVersionInfo($exe).FileVersion;
        Files = $files; TranslationTables = $tables; Processes = $processes; Logs = $logs;
        RequiredFilesMissing = @(@('sp26/bink2w64.dll','sp26/trhook.dll','sp26/rtlcompanion.dll','sp26/trdata2.bin','bink2w64.dll','trhook.dll','rtlcompanion.dll','trdata2.bin') | Where-Object { -not (Test-Path -LiteralPath (Join-Path $gameRoot ($_.Replace('/','\'))) -PathType Leaf) });
        RuntimeRenderingVerified = $false;
        Limitations = 'File/key checks do not prove that the hook intercepts every subtitle path. Module paths are collected only when accessible. No game file was modified.'
    }
    $outDir = Join-Path $Bundle 'diagnostics'
    if (-not (Test-Path -LiteralPath $outDir)) { $null = New-Item -ItemType Directory -Path $outDir }
    $out = Join-Path $outDir 'last-check.json'
    $report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $out -Encoding UTF8
    Write-Host "Saved report: $out"
    if (-not $NonInteractive) {
        [Windows.Forms.MessageBox]::Show("ตรวจไฟล์เรียบร้อยแล้ว`nรายงานอยู่ที่:`n$out`n`nหากยังมีอังกฤษหลุด ให้ส่งไฟล์ last-check.json กลับมา`nตัวตรวจไม่ได้แก้ไขไฟล์เกม", 'MW4 Thai - Check installation') | Out-Null
    }
    exit 0
} catch {
    Write-Host $_.Exception.Message
    if (-not $NonInteractive) {
        Add-Type -AssemblyName System.Windows.Forms
        [Windows.Forms.MessageBox]::Show($_.Exception.Message, 'MW4 Thai - Check failed') | Out-Null
    }
    exit 1
}
