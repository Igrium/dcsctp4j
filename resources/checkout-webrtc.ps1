<#
.SYNOPSIS
    Check out Google depot_tools and WebRTC at a given revision (Windows).
.DESCRIPTION
    Windows equivalent of resources/checkout-webrtc.sh.
#>
[CmdletBinding()]
param(
    # Directory for Google depot tools (may exist already)
    [Parameter(Mandatory = $true)][string] $DepotToolsDir,
    # Directory for the WebRTC checkout (may exist already)
    [Parameter(Mandatory = $true)][string] $WebRtcDir,
    # Revision of WebRTC to check out
    [Parameter(Mandatory = $true)][string] $Rev
)

$ErrorActionPreference = 'Stop'
$DEPOT_TOOLS_REPO = 'https://chromium.googlesource.com/chromium/tools/depot_tools.git'

# Run a native command and fail the script if it returns non-zero. PowerShell does
# not do this on its own, and $ErrorActionPreference does not apply to native exes.
function Invoke-Checked
{
    param([string] $Exe, [string[]] $Arguments)
    & $Exe @Arguments
    if ($LASTEXITCODE -ne 0)
    {
        throw "'$Exe $($Arguments -join ' ')' failed with exit code $LASTEXITCODE"
    }
}

# WebRTC's build/vs_toolchain.py recognizes only Visual Studio 2019 and 2022, and only
# in their default install locations. Newer Visual Studio releases, and installs placed
# elsewhere, make it fail with "No supported Visual Studio can be found". It honours a
# vs<year>_install environment variable, so locate a 2022-generation install ourselves
# and point it there.
function Set-VsToolchainEnv
{
    if ($env:vs2022_install -or $env:vs2019_install)
    {
        return
    }
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (-not (Test-Path -LiteralPath $vswhere))
    {
        return
    }
    # [17.0,18.0) is the 2022 generation: the newest this WebRTC revision can drive.
    $path = & $vswhere -products '*' -version '[17.0,18.0)' `
        -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
        -latest -property installationPath
    if ($path)
    {
        $env:vs2022_install = $path
        Write-Host "Using Visual Studio at $path"
    }
}

# Use the locally installed Visual Studio rather than Google's internal toolchain
# package, which is not available outside Google.
$env:DEPOT_TOOLS_WIN_TOOLCHAIN = '0'
Set-VsToolchainEnv

if (Test-Path -LiteralPath $DepotToolsDir)
{
    if (-not (Test-Path -LiteralPath (Join-Path $DepotToolsDir '.git')))
    {
        throw "$DepotToolsDir exists, but does not seem to be a Git repository"
    }
}
else
{
    $parent = Split-Path -Parent $DepotToolsDir
    if ($parent -and -not (Test-Path -LiteralPath $parent))
    {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    Invoke-Checked 'git' @('clone', $DEPOT_TOOLS_REPO, $DepotToolsDir)
}

$DepotToolsDir = (Resolve-Path -LiteralPath $DepotToolsDir).Path

# depot_tools must come first: it ships the Python, git and ninja wrappers that
# gclient/gn expect to find ahead of any other copies on the system.
$env:PATH = "$DepotToolsDir;$env:PATH"

if (Test-Path -LiteralPath (Join-Path $DepotToolsDir '.git'))
{
    Invoke-Checked (Join-Path $DepotToolsDir 'update_depot_tools.bat') @()
}

# The WebRTC tree contains paths longer than MAX_PATH.
Invoke-Checked 'git' @('config', '--global', 'core.longpaths', 'true')

# See if they specified the WebRTC src dir rather than its parent
if ((Split-Path -Leaf $WebRtcDir) -eq 'src')
{
    $WebRtcDir = Split-Path -Parent $WebRtcDir
}

$needsFetch = $true
if (Test-Path -LiteralPath $WebRtcDir)
{
    if (Test-Path -LiteralPath (Join-Path $WebRtcDir '.gclient'))
    {
        # Already existing gclient checkout; continue
        $needsFetch = $false
    }
    elseif (Get-ChildItem -LiteralPath $WebRtcDir -Force)
    {
        throw "$WebRtcDir exists, does not seem to be a gclient checkout, but is non-empty"
    }
}
else
{
    New-Item -ItemType Directory -Force -Path $WebRtcDir | Out-Null
}

Push-Location -LiteralPath $WebRtcDir
try
{
    if ($needsFetch)
    {
        Invoke-Checked (Join-Path $DepotToolsDir 'fetch.bat') @('--nohooks', 'webrtc')
    }
    Invoke-Checked (Join-Path $DepotToolsDir 'gclient.bat') @('sync', '-r', $Rev, '-D')
}
finally
{
    Pop-Location
}
