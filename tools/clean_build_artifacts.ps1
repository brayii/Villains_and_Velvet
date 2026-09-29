<#
.SYNOPSIS
Removes regenerable local build and verification artifacts from the project.

.DESCRIPTION
Local GameMaker verification runs write every scratch directory into
.build_temp/ instead of reusing a single location, so the tree grew to
thousands of entries and tens of gigabytes. Once that happens, Git commands
that walk the work tree start failing with "Filename too long" warnings from
the Android intermediates, because those paths exceed the legacy Windows
MAX_PATH limit.

This tool deletes only paths that Git already ignores, and only after
confirming with `git check-ignore` that each target is ignored. Anything
tracked is therefore never at risk.

Targets:
  .build_temp   per-run scratch: build outputs, caches, APKs, screenshots, logs
  cache         GameMaker local compilation cache
  output        last local build output
  .release      collected release packages
  .build_cache  local verification cache
  .build_output local verification output
  .runtime_test local runtime test output
  Build         GMRT build directory

.PARAMETER Execute
Actually delete. Without this switch the tool only reports what it would remove.

.PARAMETER Target
Limit the run to one target directory name.

.PARAMETER Keep
Do not delete a target directory. Useful for preserving the last release
packages, or the current build output while debugging.

.EXAMPLE
powershell -ExecutionPolicy Bypass -File tools\clean_build_artifacts.ps1

.EXAMPLE
powershell -ExecutionPolicy Bypass -File tools\clean_build_artifacts.ps1 -Execute

.EXAMPLE
powershell -ExecutionPolicy Bypass -File tools\clean_build_artifacts.ps1 -Execute -Keep .release
#>
param(
    [switch]$Execute,
    [string]$Target,
    [string[]]$Keep = @()
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

# Scratch space for the long-path mirror lives inside the project so this tool
# creates no files outside the repository. See Remove-Tree below.
$StagingRoot = Join-Path $ProjectRoot 'tools\.clean-staging'

$Targets = @('.build_temp', '.build_cache', '.build_output', '.runtime_test', 'Build', 'cache', 'output', '.release')

function Get-TreeSize([string]$Path) {
    $files = Get-ChildItem -LiteralPath $Path -Recurse -File -Force -ErrorAction SilentlyContinue |
        Measure-Object -Property Length -Sum
    return [pscustomobject]@{ Files = $files.Count; Megabytes = [Math]::Round($files.Sum / 1MB, 1) }
}

# Git writes progress and errors to stderr, which PowerShell surfaces as a
# terminating NativeCommandError under $ErrorActionPreference = 'Stop'. The
# helper below neutralizes that so only the exit code is consulted.
function Invoke-Git([string[]]$Arguments) {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & git -C $ProjectRoot @Arguments 2>&1
        return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
    } finally {
        $ErrorActionPreference = $previous
    }
}

# Plain ls-files avoids --error-unmatch, which fails loudly for untracked paths.
function Test-Tracked([string]$RelativePath) {
    $result = Invoke-Git @('ls-files', '--', $RelativePath)
    if ($result.ExitCode -ne 0) { throw "git ls-files failed: $($result.Output)" }
    return (@($result.Output).Count -gt 0)
}

function Test-Ignored([string]$RelativePath) {
    return ((Invoke-Git @('check-ignore', '-q', '--', $RelativePath)).ExitCode -eq 0)
}

# Windows MAX_PATH blocks Remove-Item on deep Android intermediates, so an empty
# directory is mirrored over the target. robocopy clears those long entries
# without touching the paths PowerShell cannot open.
#
# The empty staging directory is created inside the project rather than in the
# OS temp directory, so this tool never writes outside the repository. It sits
# under tools/ and is gitignored, and is removed in the finally block.
function Remove-Tree([string]$Path) {
    $staging = Join-Path $StagingRoot ([Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $staging | Out-Null
    try {
        $previous = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        # Robocopy reports 0-7 for success, including the >1 codes used when it
        # only deleted extra files. Only 8 and above mean real failure.
        & robocopy $staging $Path /MIR /NFL /NDL /NJH /NJS /NP /R:0 /W:0 | Out-Null
        $robocopyCode = $LASTEXITCODE
        $ErrorActionPreference = $previous
        if ($robocopyCode -ge 8) { throw "robocopy failed with exit code $robocopyCode" }
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue
    } finally {
        Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue
    }
    return (-not (Test-Path -LiteralPath $Path))
}

$plan = @()
foreach ($name in $Targets) {
    if ($Target -and $name -ne $Target) { continue }
    if ($Keep -contains $name) { Write-Output "skip (kept):  $name"; continue }
    $path = Join-Path $ProjectRoot $name
    if (-not (Test-Path -LiteralPath $path)) { continue }

    # Refuse to delete anything Git tracks, whatever the ignore rules say.
    if (Test-Tracked $name) {
        Write-Warning "refusing to remove tracked path: $name"
        continue
    }
    if (-not (Test-Ignored $name)) {
        Write-Warning "not ignored by Git, leaving in place: $name"
        continue
    }

    $size = Get-TreeSize $path
    if ($size.Files -eq 0) { continue }
    $plan += [pscustomobject]@{ Name = $name; Path = $path; Files = $size.Files; Megabytes = $size.Megabytes }
}

if ($plan.Count -eq 0) {
    Write-Output 'Nothing to clean.'
    exit 0
}

$plan | Format-Table -AutoSize
$totalFiles = ($plan | Measure-Object -Property Files -Sum).Sum
$totalMegabytes = ($plan | Measure-Object -Property Megabytes -Sum).Sum
Write-Output ('Total: {0} files, {1} MB' -f $totalFiles, $totalMegabytes)

if (-not $Execute) {
    Write-Output ''
    Write-Output 'Dry run only. Re-run with -Execute to delete.'
    exit 0
}

Write-Output ''
New-Item -ItemType Directory -Force -Path $StagingRoot | Out-Null
try {
    foreach ($entry in $plan) {
        if (Remove-Tree $entry.Path) {
            Write-Output ('removed: {0} ({1} files, {2} MB)' -f $entry.Name, $entry.Files, $entry.Megabytes)
        } else {
            Write-Warning ('incomplete removal: {0}' -f $entry.Name)
        }
    }
} finally {
    Remove-Item -LiteralPath $StagingRoot -Recurse -Force -ErrorAction SilentlyContinue
}
