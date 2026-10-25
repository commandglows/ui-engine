<#
.SYNOPSIS
Publishes a validated release to the public releases repository read by
shipglows_updater.

.DESCRIPTION
- Versioned release `<app>-v<version>` (the `+` becomes `-`): the APK and/or
  the Windows installer, never replaced once published.
- Rolling release `<app>-latest`: `android.json` (written here: version, URL,
  SHA-256, size) and `appcast.xml` (from the app's own Windows packaging,
  signed with its DSA key), replaced on every publish. The apps read:
    https://github.com/<repo>/releases/download/<app>-latest/android.json
    https://github.com/<repo>/releases/download/<app>-latest/appcast.xml

The Windows appcast must point at the versioned release: package it with
  -DownloadBaseUrl https://github.com/<repo>/releases/download/<app>-v<version>
Needs `gh` signed in with write access to the repository.

.EXAMPLE
.\publish-release.ps1 -Repo <owner>/shipglows-releases -App contentglows `
  -PubspecPath ..\..\..\contentglows\app\pubspec.yaml `
  -Apk ..\..\..\contentglows\app\build\app\outputs\flutter-apk\app-release.apk
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$Repo,
    # Lowercase app slug, the tag prefix: contentglows, replayglows…
    [Parameter(Mandatory)] [ValidatePattern('^[a-z0-9][a-z0-9-]*$')] [string]$App,
    # Pubspec version (1.2.3+45); read from -PubspecPath when omitted.
    [string]$Version = '',
    [string]$PubspecPath = '.\pubspec.yaml',
    [string]$Apk = '',
    [string]$WindowsInstaller = '',
    [string]$Appcast = '',
    [string]$NotesUrl = ''
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not $Apk -and -not $WindowsInstaller) { throw 'Give -Apk and/or -WindowsInstaller.' }
if ($WindowsInstaller -and -not $Appcast) { throw '-WindowsInstaller needs the signed -Appcast generated with it.' }
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { throw 'gh was not found.' }

if (-not $Version) {
    $line = Select-String -LiteralPath $PubspecPath -Pattern '^version:\s*(\S+)\s*$'
    if (-not $line) { throw "No version in $PubspecPath." }
    $Version = $line.Matches[0].Groups[1].Value
}
if ($Version -notmatch '^\d+(\.\d+)*(\+\d+)?$') { throw "Bad version $Version." }
if ($Apk -and $Version -notmatch '\+\d+$') {
    throw 'An Android release needs a build number (1.2.3+45): it is the versionCode.'
}

$slug = $Version.Replace('+', '-')
$tag = "$App-v$slug"
$latestTag = "$App-latest"
$baseUrl = "https://github.com/$Repo/releases/download"

function Test-Release([string]$name) {
    gh release view $name --repo $Repo *> $null
    return $LASTEXITCODE -eq 0
}

$work = Join-Path ([System.IO.Path]::GetTempPath()) ("sg-release-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $work | Out-Null
try {
    # Versioned assets under stable, readable names.
    $assets = @()
    if ($Apk) {
        $apkAsset = Join-Path $work "$App-$slug.apk"
        Copy-Item -LiteralPath (Resolve-Path -LiteralPath $Apk).Path -Destination $apkAsset
        $assets += $apkAsset
    }
    if ($WindowsInstaller) {
        $assets += (Resolve-Path -LiteralPath $WindowsInstaller).Path
    }

    if (Test-Release $tag) {
        # A published version never changes: refuse to replace its files.
        $existing = gh release view $tag --repo $Repo --json assets --jq '.assets[].name'
        foreach ($asset in $assets) {
            if ($existing -contains (Split-Path -Leaf $asset)) {
                throw "$tag already has $(Split-Path -Leaf $asset); bump the version."
            }
        }
        gh release upload $tag @assets --repo $Repo
    } else {
        gh release create $tag @assets --repo $Repo --title "$App $Version" --notes "$App $Version" --latest=false
    }
    if ($LASTEXITCODE -ne 0) { throw "Publishing $tag failed." }

    $feeds = @()
    if ($Apk) {
        $file = Get-Item -LiteralPath $apkAsset
        $manifest = [ordered]@{
            version     = $Version
            url         = "$baseUrl/$tag/$($file.Name)"
            sha256      = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
            size        = $file.Length
            publishedAt = [DateTimeOffset]::UtcNow.ToString('o')
        }
        if ($NotesUrl) { $manifest.notesUrl = $NotesUrl }
        $json = Join-Path $work 'android.json'
        [System.IO.File]::WriteAllText($json, ($manifest | ConvertTo-Json) + "`n", [System.Text.UTF8Encoding]::new($false))
        $feeds += $json
    }
    if ($Appcast) {
        $appcastPath = (Resolve-Path -LiteralPath $Appcast).Path
        if ((Get-Content -Raw -LiteralPath $appcastPath) -notmatch [regex]::Escape("$baseUrl/$tag/")) {
            throw "The appcast does not point at $baseUrl/$tag/; package it with that -DownloadBaseUrl."
        }
        # The apps read it under this exact name.
        $appcastAsset = Join-Path $work 'appcast.xml'
        Copy-Item -LiteralPath $appcastPath -Destination $appcastAsset
        $feeds += $appcastAsset
    }

    # The feeds go last: an app never sees a version whose files are missing.
    if (Test-Release $latestTag) {
        gh release upload $latestTag @feeds --repo $Repo --clobber
    } else {
        gh release create $latestTag @feeds --repo $Repo --title "$App (latest)" --notes 'Update feeds read by the app. Do not delete.' --latest=false
    }
    if ($LASTEXITCODE -ne 0) { throw "Updating $latestTag failed." }

    Write-Host "Published $App $Version ($tag)."
    if ($Apk) { Write-Host "Android manifest: $baseUrl/$latestTag/android.json" }
    if ($Appcast) { Write-Host "Windows appcast:  $baseUrl/$latestTag/appcast.xml" }
} finally {
    Remove-Item -LiteralPath $work -Recurse -Force
}
