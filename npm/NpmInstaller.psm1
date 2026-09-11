# npm adapter. The existing Windows launcher remains the runtime implementation.
Set-StrictMode -Version Latest

function Assert-NpmDrive {
    param([string]$Root)
    if ($Root -notmatch '^[A-Za-z]:\\$') { throw 'Choose an SSD drive root, such as E:\.' }
    Assert-T5PlainPath $Root
    $drive = [IO.DriveInfo]::new($Root)
    if (-not $drive.IsReady) { throw "Drive $Root is not connected or ready." }
    if ($drive.DriveType -notin @([IO.DriveType]::Fixed, [IO.DriveType]::Removable)) {
        throw 'Use a local external drive, not a network share.'
    }
    if ($drive.DriveFormat -notin @('NTFS','exFAT')) { throw 'Use an existing NTFS or exFAT volume. Setup never formats a drive.' }
    $systemRoot = [IO.Path]::GetPathRoot([Environment]::GetFolderPath('Windows'))
    $serial = Get-T5VolumeSerial $Root
    if ($serial -eq (Get-T5VolumeSerial $systemRoot)) { throw 'Do not use the Windows system volume as the model SSD.' }
    $profileRoot = [IO.Path]::GetPathRoot((Get-T5HostPaths).Profile)
    if ($serial -eq (Get-T5VolumeSerial $profileRoot)) { throw 'Do not use the Windows profile volume as the model SSD.' }
    $serial
}

function Get-NpmPayloadPlan {
    param([string]$PackageRoot, [string]$Destination)
    Assert-T5PlainPath $Destination
    if (-not (Test-Path -LiteralPath $Destination -PathType Container)) { throw 'The destination directory does not exist.' }
    $names = Get-Content -LiteralPath (Join-Path $PackageRoot 'npm\payload.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($null -eq $names -or @($names).Count -eq 0) { throw 'The package payload list is empty. Reinstall the npm package.' }
    if ($names -isnot [array]) { throw 'Invalid package payload list. Reinstall the npm package.' }
    $seen = @{}
    foreach ($name in $names) {
        if ($name -isnot [string] -or $name -notmatch '^(T5-Launcher/)?[A-Za-z0-9][A-Za-z0-9._-]*$' -or $seen.ContainsKey($name)) {
            throw 'Invalid or duplicate package payload entry. Reinstall the npm package.'
        }
        $seen[$name] = $true
        $source = Join-Path $PackageRoot $name
        $target = Join-Path $Destination $name
        Assert-T5PlainPath $source
        Assert-T5PlainPath $target
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Package file missing: $name. Reinstall the npm package." }
        $hash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
        $exists = Test-Path -LiteralPath $target
        if ($exists -and (-not (Test-Path -LiteralPath $target -PathType Leaf) -or
                (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne $hash)) {
            throw "Existing file differs: $target. Nothing was overwritten. See docs/npm.md for version replacement steps."
        }
        [pscustomobject]@{Name=$name;Source=$source;Target=$target;Hash=$hash;Exists=$exists}
    }
}

function Copy-NpmPayload {
    param([object[]]$Plan)
    # Preflight the entire plan before writing any file. Exclusive creation also
    # protects files created by another process after this check.
    foreach ($item in $Plan) {
        Assert-T5PlainPath $item.Source
        Assert-T5PlainPath $item.Target
        if ((Get-FileHash -LiteralPath $item.Source -Algorithm SHA256).Hash -ne $item.Hash) { throw 'The npm package changed during setup. Run setup again.' }
        if (Test-Path -LiteralPath $item.Target) {
            if (-not (Test-Path -LiteralPath $item.Target -PathType Leaf) -or
                    (Get-FileHash -LiteralPath $item.Target -Algorithm SHA256).Hash -ne $item.Hash) {
                throw "Destination changed during setup: $($item.Target). Nothing was overwritten."
            }
        }
    }
    foreach ($item in $Plan) {
        Assert-T5PlainPath $item.Target
        if (Test-Path -LiteralPath $item.Target) {
            if (-not (Test-Path -LiteralPath $item.Target -PathType Leaf) -or
                    (Get-FileHash -LiteralPath $item.Target -Algorithm SHA256).Hash -ne $item.Hash) { throw "Destination changed during setup: $($item.Target). Nothing was overwritten." }
            continue
        }
        [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($item.Target))
        $bytes = [IO.File]::ReadAllBytes($item.Source)
        $stream = [IO.File]::Open($item.Target,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
        try { $stream.Write($bytes,0,$bytes.Length) } finally { $stream.Dispose() }
        if ((Get-FileHash -LiteralPath $item.Target -Algorithm SHA256).Hash -ne $item.Hash) { throw "Copy verification failed: $($item.Name). Re-run setup to inspect the partial installation." }
    }
}

function Assert-NpmRuntime {
    param([string]$PackageRoot, [string]$Drive)
    # Never execute an unknown script from a removable drive. Only the four
    # scripts imported or run by the adapter need to match the npm release.
    foreach ($name in @('T5Launcher.ps1','T5Launcher.psm1','Configure-SSD.ps1','Create-Desktop-Shortcut.ps1')) {
        $source = Join-Path $PackageRoot ('T5-Launcher\' + $name)
        $target = Join-Path $Drive ('T5-Launcher\' + $name)
        Assert-T5PlainPath $source
        Assert-T5PlainPath $target
        if (-not (Test-Path -LiteralPath $target -PathType Leaf)) { throw 'Launcher files are missing. Run portable-ai setup --drive with this SSD drive letter first.' }
        if ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash) {
            throw 'The SSD launcher differs from this npm version. See docs/npm.md for version replacement steps.'
        }
    }
}

Export-ModuleMember -Function Assert-NpmDrive,Get-NpmPayloadPlan,Copy-NpmPayload,Assert-NpmRuntime
