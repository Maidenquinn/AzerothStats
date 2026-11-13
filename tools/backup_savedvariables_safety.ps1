# Read-only safety utility for native migration acceptance. Windows PowerShell 5.1+.
# Does NOT change the addon, the game's original files, or any backup root.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SourceSavedDirectory,
    [Parameter(Mandatory = $true)]
    [string]$DestinationRoot,
    [switch]$GameCompletelyClosed
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $GameCompletelyClosed) {
    throw "Fully quit the game first, then pass -GameCompletelyClosed explicitly."
}

$source = [System.IO.Path]::GetFullPath($SourceSavedDirectory).TrimEnd('\', '/')
$targetRoot = [System.IO.Path]::GetFullPath($DestinationRoot).TrimEnd('\', '/')
if (-not (Test-Path -LiteralPath $source -PathType Container)) {
    throw "Source directory does not exist."
}
if ($targetRoot.StartsWith($source + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase) -or
    $targetRoot.Equals($source, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Destination must be outside the game's SavedVariables folder."
}

$names = @("AzerothStats.lua", "AzerothStatsBackup.lua", "AzerothStatsAutoBackup.lua")
$existing = @($names | Where-Object { Test-Path -LiteralPath (Join-Path $source $_) -PathType Leaf })
if ($existing.Count -eq 0) {
    throw "No Azeroth Stats SavedVariables files found. No directories were changed."
}

$session = "azerothstats-safety-{0}-{1}" -f (Get-Date -Format "yyyyMMdd-HHmmss"), ([guid]::NewGuid().ToString("N").Substring(0, 8))
$target = Join-Path $targetRoot $session
$null = New-Item -ItemType Directory -Path $target -Force:$false
$manifest = @()
foreach ($name in $existing) {
    $original = Join-Path $source $name
    $copy = Join-Path $target $name
    Copy-Item -LiteralPath $original -Destination $copy -ErrorAction Stop
    $originalHash = (Get-FileHash -LiteralPath $original -Algorithm SHA256).Hash
    $copyHash = (Get-FileHash -LiteralPath $copy -Algorithm SHA256).Hash
    $originalBytes = (Get-Item -LiteralPath $original).Length
    $copyBytes = (Get-Item -LiteralPath $copy).Length
    if ($originalHash -ne $copyHash -or $originalBytes -ne $copyBytes) {
        throw "Verification mismatch for $name. Keep originals untouched."
    }
    $manifest += [PSCustomObject]@{
        name = $name
        bytes = $originalBytes
        sha256 = $originalHash
    }
}
$report = [PSCustomObject]@{
    createdUtc = (Get-Date).ToUniversalTime().ToString("o")
    count = $existing.Count
    files = $manifest
    verification = "SHA256 and byte length matched after copy"
}
$report | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $target "manifest.json") -Encoding UTF8
Write-Host "Verified read-only backup: $target"
Write-Host "Files: $($existing.Count). Original game saves were not changed."
